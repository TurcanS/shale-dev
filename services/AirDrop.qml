pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/airdrop.js" as Words

// AirDrop with iPhones, iPads and Macs through the optional `airdrop` command (AirDrop for Linux), driven over its
// --json interface: it reports what happens as JSON lines and takes picks and answers on stdin. One process sends
// (`airdrop send`), one receives (`receive` while Visible, `listen` in Background); the radio takes one session at a
// time, so receiving pauses while a send runs and comes back after it. Everything here is hidden while the command
// is missing or too old to speak --json.
Singleton {
    id: root

    // ---- the command ----------------------------------------------------------------------------------------------
    readonly property string command: Backend.capabilities.airdrop || ""
    // The installed command answers `--json config show`.
    property bool supported: false
    readonly property bool available: command !== "" && supported
    // {name, dir, known, mode, channel, iface}: the command's own settings (its device name and known senders).
    property var config: ({})
    readonly property string deviceName: config.name || ""
    readonly property var knownSenders: config.known || []
    // `airdrop doctor`: {ok, checks: [{label, detail, level: ok | error | info}]}, after checkComputer().
    property var doctor: null
    property bool checking: false
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string folder: ShellState.setting("airdropFolder", "~/Downloads/AirDrop")
    readonly property string folderPath: folder.startsWith("~/") ? home + folder.slice(1) : folder
    // A hidden way to try the panel without a radio: SHALE_AIRDROP_PEER=[::1]:PORT sends to that receiver, and
    // SHALE_AIRDROP_BIND=::1 receives there (the command's own loopback test mode).
    readonly property string devPeer: Quickshell.env("SHALE_AIRDROP_PEER") || ""
    readonly property string devBind: Quickshell.env("SHALE_AIRDROP_BIND") || ""
    onCommandChanged: probe()

    // ---- receiving ------------------------------------------------------------------------------------------------
    // off | visible (for ten minutes, `receive`) | background (`listen`: Wi-Fi stays up until an iPhone opens AirDrop)
    property string mode: "off"
    readonly property int visibleMinutes: 10
    property real visibleUntil: 0
    property int visibleLeft: 0
    // While receiving: starting | ready (visible) | listening (background, idle) | waking (an iPhone opened AirDrop)
    property string receiverState: ""
    property bool receiverWifi: false
    property bool senderWifi: false
    readonly property bool wifiPaused: receiverWifi || senderWifi
    // Requests from other devices, newest last; a card per row. Arrays are JSON text (a ListModel can't hold them).
    // key: "<generation>:<id>", the id being the command's own (it starts again at 1 in each receiver process).
    property ListModel incoming: ListModel {}
    property int generation: 0
    // Questions waiting for an answer.
    property int countPending: 0
    // The request whose files are arriving now: {key, sender, done, total} or null.
    property var incomingNow: null
    // Sent and received this session, newest first: {dir: in | out, who, title, bytes, paths, url, phase, time}.
    property var recent: []

    // ---- sending --------------------------------------------------------------------------------------------------
    // "" | starting (the radio comes up) | searching | ended (nothing picked for a while; search again)
    property string sendState: ""
    // Devices nearby: peerId, name, model, kind, available, lost, phase ("" | asking | sending | done | declined |
    // failed | cancelled), transferId, done, total, message.
    property ListModel peers: ListModel {}
    // What is chosen to send: [{path, name, size, dir, kind}], or one link.
    property var staged: []
    property string stagedUrl: ""
    readonly property bool hasStaged: staged.length > 0 || stagedUrl !== ""
    readonly property real stagedBytes: staged.reduce((sum, item) => sum + (item.size || 0), 0)
    // The send that is running, for the bar: {peerId, name, phase, done, total} or null.
    property var sending: null
    property string searchHint: ""

    // ---- what went wrong ------------------------------------------------------------------------------------------
    // {code, message, hint}; code is the command's (auth, helper, busy, link, bluetooth, config, start, input) or exit.
    property var error: null
    readonly property var hints: ({
        auth: "Shale wasn't given permission to use the Wi-Fi card. To stop being asked, install the polkit rule from the airdrop source folder: packaging/50-airdrop-background.rules.example.",
        helper: "The airdrop helper is missing or older than the airdrop command. Settings → AirDrop → Check this computer says how to install it.",
        busy: "Another AirDrop session is running, perhaps in a terminal. Stop it and try again.",
        bluetooth: "Bluetooth is off or missing. Background needs it to hear an iPhone open AirDrop.",
        link: "The Wi-Fi card couldn't start AirDrop. Settings → AirDrop → Check this computer may say why.",
        config: "The airdrop command's settings file can't be read.",
        start: "AirDrop couldn't start receiving.",
        input: ""
    })
    function fail(code, message) {
        error = {code: code, message: message || "AirDrop stopped", hint: hints[code] || ""};
    }

    // ---- what the bar and the panel read ---------------------------------------------------------------------------
    readonly property bool receiving: receiver.running
    readonly property bool looking: sender.running
    // 0–1 of whatever moves now, or -1.
    readonly property real progress: {
        if (sending && sending.phase === "sending" && sending.total > 0)
            return Math.min(1, sending.done / sending.total);
        return incomingNow && incomingNow.total > 0 ? Math.min(1, incomingNow.done / incomingNow.total) : -1;
    }
    readonly property bool active: mode !== "off" || looking || progress >= 0 || countPending > 0

    // ---- receiving: modes -----------------------------------------------------------------------------------------
    // Off and Background are kept as the start-up choice; Visible lasts ten minutes and is never restored.
    function setMode(next, keep) {
        if (!available || ["off", "visible", "background"].indexOf(next) < 0)
            return;
        if (next !== "visible" && keep !== false)
            ShellState.setSetting("airdropMode", next);
        if (next === "visible")
            visibleUntil = Date.now() + visibleMinutes * 60000;
        error = null;
        mode = next;
        if (sender.running) {
            resumeMode = next; // after the send
            return;
        }
        restartReceiver();
    }
    function toggleVisible() {
        setMode(mode === "visible" ? (ShellState.setting("airdropMode", "off") === "background" ? "background" : "off") : "visible");
    }
    function extend() {
        if (mode === "visible")
            visibleUntil = Math.max(visibleUntil, Date.now()) + visibleMinutes * 60000;
    }
    property string resumeMode: ""
    property string startMode: ""
    // Asking, the time to answer and the folder are given when the receiver starts; a change starts it again.
    readonly property string receiverSettings: [ShellState.setting("airdropAsk", "ask"), ShellState.setting("airdropTimeout", 60), folderPath].join("|")
    onReceiverSettingsChanged: if (receiver.running && !receiver.stopping && countPending === 0 && !incomingNow)
        restartReceiver()
    function restartReceiver() {
        if (receiver.running) {
            stopProcess(receiver);
            return; // onExited starts the mode that is chosen then
        }
        startReceiver();
    }
    function receiverCommand(kind) {
        const args = [command, "--json", kind];
        if (kind === "receive" && devBind)
            args.push("--no-link", "--bind", devBind, "--port", Quickshell.env("SHALE_AIRDROP_PORT") || "0");
        if (ShellState.setting("airdropAsk", "ask") === "ask")
            args.push("--ask", "--ask-timeout", String(ShellState.setting("airdropTimeout", 60)));
        args.push("--download-dir", folderPath);
        return args;
    }
    function startReceiver() {
        if (mode === "off" || receiver.running || sender.running)
            return;
        generation++;
        startMode = mode;
        receiverState = "starting";
        receiver.command = receiverCommand(mode === "visible" ? "receive" : "listen");
        receiver.running = true;
    }
    property Timer visibleClock: Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.mode === "visible"
        onTriggered: {
            root.visibleLeft = Math.max(0, Math.round((root.visibleUntil - Date.now()) / 1000));
            // Not in the middle of a question or a transfer: it ends right after.
            if (root.visibleLeft === 0 && root.countPending === 0 && !root.incomingNow)
                root.setMode(ShellState.setting("airdropMode", "off") === "background" ? "background" : "off", false);
        }
    }

    // ---- receiving: answers ---------------------------------------------------------------------------------------
    function answer(key, decision) {
        const i = indexOf(incoming, "key", key);
        if (i < 0)
            return;
        const row = incoming.get(i);
        if (row.phase !== "asking")
            return;
        // The lock screen never says Always: a sender named there is not someone the owner looked at.
        const choice = decision === "always" && ShellState.locked ? "accept" : decision;
        if (receiver.running && row.generation === generation)
            receiver.write(JSON.stringify({answer: choice, id: row.rid}) + "\n");
        incoming.setProperty(i, "phase", choice === "decline" ? "declined" : "accepted");
        incoming.setProperty(i, "decision", choice);
        countAsking();
    }
    // The oldest open question (`shale airdrop accept|decline`, bindable keys).
    function answerOldest(decision) {
        for (let i = 0; i < incoming.count; i++)
            if (incoming.get(i).phase === "asking")
                return answer(incoming.get(i).key, decision);
    }
    function dismiss(key) {
        const i = indexOf(incoming, "key", key);
        if (i < 0)
            return;
        if (incoming.get(i).phase === "asking")
            answer(key, "decline");
        incoming.remove(i);
        countAsking();
    }
    function countAsking() {
        let n = 0;
        for (let i = 0; i < incoming.count; i++)
            if (incoming.get(i).phase === "asking")
                n++;
        countPending = n;
    }
    // Only web links open, and only from a request someone accepted.
    function openLink(url) {
        if (/^https?:\/\//i.test(url) && !ShellState.locked)
            ShellState.openUrl(url);
    }
    // Undo a session that ended badly (Wi-Fi still paused): the command's own recovery, with a password if asked.
    function recover() {
        if (receiver.running || sender.running)
            return;
        error = null;
        run(["recover"], null, code => ShellState.message(code === 0 ? "Wi-Fi is back" : "Couldn't give Wi-Fi back; run airdrop recover in a terminal",
                                                           code === 0 ? "success" : "error"));
    }
    function forget(sender) {
        run(["config", "known", "rm", sender], null, () => refreshConfig());
    }
    function rename(name) {
        const clean = String(name || "").trim();
        if (clean && clean !== deviceName)
            run(["config", "set", "name", clean], null, code => {
                if (code !== 0)
                    ShellState.message("Couldn't rename this computer for AirDrop", "error");
                refreshConfig();
            });
    }

    // ---- sending --------------------------------------------------------------------------------------------------
    // Staging asks the helper which paths exist and how big they are, so the card can show sizes.
    function stage(paths) {
        const wanted = (paths || []).map(path => String(path).replace(/^file:\/\//, "")).map(path => {
            try {
                return decodeURIComponent(path);
            } catch (e) {
                return path;
            }
        }).filter(path => path.startsWith("/") && !staged.some(item => item.path === path));
        if (!wanted.length)
            return;
        stagedUrl = "";
        Backend.request("airdrop.stat", {paths: wanted.slice(0, 200)}, (result, error) => {
            if (error)
                return;
            const added = result.items.filter(item => !root.staged.some(old => old.path === item.path));
            root.staged = root.staged.concat(added);
            if (added.length < wanted.length)
                ShellState.message(wanted.length - added.length === 1 ? "One item can't be found" : (wanted.length - added.length) + " items can't be found", "error");
        });
    }
    function stageUrl(url) {
        const text = String(url || "").trim();
        if (!/^[a-z][a-z0-9+.-]*:\S+$/i.test(text))
            return false;
        staged = [];
        stagedUrl = text;
        return true;
    }
    function unstage(index) {
        if (index < 0)
            stagedUrl = "";
        else
            staged = staged.filter((item, i) => i !== index);
    }
    function clearStaged() {
        staged = [];
        stagedUrl = "";
    }
    // Look for devices: the radio comes up (in borrow mode Wi-Fi pauses for the search), so only when asked.
    function search() {
        if (!available || sender.running)
            return;
        error = null;
        searchHint = "";
        if (receiver.running) {
            resumeMode = mode;
            pendingSearch = true;
            stopProcess(receiver);
            return;
        }
        startSender();
    }
    property bool pendingSearch: false
    function startSender() {
        pendingSearch = false;
        for (let i = peers.count - 1; i >= 0; i--)
            if (peers.get(i).lost || ["", "done", "declined", "failed", "cancelled"].indexOf(peers.get(i).phase) >= 0)
                peers.remove(i);
        sendState = "starting";
        const args = [command, "--json", "send", "-t", "90"];
        if (devPeer)
            args.push("--peer", devPeer);
        sender.command = args;
        sender.running = true;
    }
    // The panel closed: stop looking unless something is on its way.
    function endSearch() {
        if (sender.running && !(sending && ["asking", "sending"].indexOf(sending.phase) >= 0))
            stopProcess(sender);
    }
    function sendTo(peerId) {
        const i = indexOf(peers, "peerId", peerId);
        if (i < 0 || !hasStaged || !sender.running || sending && ["asking", "sending"].indexOf(sending.phase) >= 0)
            return;
        const row = peers.get(i);
        if (!row.available || row.lost)
            return;
        const pick = stagedUrl ? {pick: peerId, url: stagedUrl} : {pick: peerId, paths: staged.map(item => item.path)};
        sender.write(JSON.stringify(pick) + "\n");
        // Shown at once; the command confirms with its transfer id.
        peers.setProperty(i, "phase", "asking");
        peers.setProperty(i, "transferId", -1);
        peers.setProperty(i, "done", 0);
        peers.setProperty(i, "total", stagedBytes);
        peers.setProperty(i, "message", "");
        sending = {peerId: peerId, name: row.name, phase: "asking", done: 0, total: stagedBytes, title: stagedTitle()};
    }
    function cancel(peerId) {
        const i = indexOf(peers, "peerId", peerId);
        if (i >= 0 && peers.get(i).transferId > 0 && sender.running)
            sender.write(JSON.stringify({cancel: peers.get(i).transferId}) + "\n");
    }
    function stagedTitle() {
        if (stagedUrl)
            return stagedUrl.replace(/^https?:\/\//, "");
        if (staged.length === 1)
            return staged[0].name;
        return staged.length + " items";
    }

    // ---- events ---------------------------------------------------------------------------------------------------
    function handle(from, line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (ev.event === "error") {
            // A pick the command couldn't take: the device row says so.
            if (ev.code === "input" || ev.code === "busy" && from === "tx") {
                if (sending) {
                    setPeer(sending.peerId, {phase: "failed", message: ev.message});
                    sending = null;
                }
                return;
            }
            fail(ev.code, ev.message);
        } else if (ev.event === "session") {
            const paused = ev.phase === "up" && !!ev.wifi_paused;
            if (from === "rx")
                receiverWifi = paused;
            else
                senderWifi = paused;
            if (ev.phase === "starting" && from === "rx" && startMode === "background")
                receiverState = "waking";
        } else if (ev.event === "visible" && from === "rx") {
            receiverState = "ready";
            error = null;
        } else if (ev.event === "listen") {
            receiverState = ev.state === "triggered" ? "waking" : "listening";
            if (ev.state === "idle")
                error = null;
        } else if (ev.event === "searching") {
            sendState = "searching";
        } else if (ev.event === "search_end") {
            sendState = "ended";
            searchHint = ev.found ? "" : ev.hint || "";
        } else if (ev.event === "peer") {
            const fields = {name: ev.name || ev.model || "Unknown device", model: ev.model || "", kind: ev.kind || "other",
                            available: !!ev.available, lost: false};
            if (indexOf(peers, "peerId", ev.id) < 0)
                peers.append(Object.assign({peerId: ev.id, phase: "", transferId: 0, done: 0, total: 0, message: ""}, fields));
            else
                setPeer(ev.id, fields);
        } else if (ev.event === "peer_lost") {
            setPeer(ev.id, {lost: true});
        } else if (ev.event === "ask") {
            incoming.append({
                key: generation + ":" + ev.id, rid: ev.id, generation: generation,
                sender: ev.sender || "", model: ev.model || "", kind: ev.kind || "other",
                known: !!ev.known, asking: !!ev.asking, timeout: ev.timeout || 0,
                deadline: Date.now() + (ev.timeout || 0) * 1000, created: Date.now(),
                filesJson: JSON.stringify(ev.files || []), urlsJson: JSON.stringify(ev.urls || []),
                total: ev.total || 0, icon: ev.icon ? "file://" + ev.icon : "",
                phase: ev.asking ? "asking" : "accepted", decision: ev.asking ? "" : "accept",
                done: 0, rate: 0, savedJson: "[]", message: "", finished: 0
            });
            countAsking();
        } else if (ev.event === "answered") {
            updateIncoming(ev.id, row => row.phase === "asking" || row.phase === "accepted" ? {
                phase: ev.decision === "decline" ? (ev.by === "timeout" ? "missed" : "declined") : "accepted",
                decision: ev.decision, finished: ev.decision === "decline" ? Date.now() : 0
            } : {});
            countAsking();
        } else if (ev.event === "link") {
            updateIncoming(ev.id, row => ({phase: "link", savedJson: JSON.stringify([ev.url]), finished: Date.now()}));
            remember({dir: "in", who: ev.sender || "", title: ev.url, url: ev.url, phase: "done"});
        } else if (ev.event === "progress") {
            if (from === "rx") {
                updateIncoming(ev.id, row => ({done: ev.done, total: ev.total || row.total, rate: ev.rate || 0}));
                if (incomingNow && incomingNow.key === generation + ":" + ev.id)
                    incomingNow = Object.assign({}, incomingNow, {done: ev.done, total: ev.total || incomingNow.total});
            } else
                setTransfer(ev.id, {done: ev.done, total: ev.total || 0});
        } else if (ev.event === "transfer") {
            if (ev.dir === "in")
                incomingTransfer(ev);
            else
                outgoingTransfer(ev);
        }
    }
    function incomingTransfer(ev) {
        const i = indexOf(incoming, "key", generation + ":" + ev.id);
        const row = i >= 0 ? incoming.get(i) : null;
        if (ev.phase === "receiving") {
            updateIncoming(ev.id, row => ({phase: "receiving", total: ev.total || row.total}));
            incomingNow = {key: generation + ":" + ev.id, sender: ev.sender || (row ? row.sender : ""), done: 0, total: ev.total || (row ? row.total : 0)};
            return;
        }
        if (incomingNow && incomingNow.key === generation + ":" + ev.id)
            incomingNow = null;
        if (ev.phase === "done") {
            const saved = ev.saved || [];
            updateIncoming(ev.id, () => ({phase: "done", savedJson: JSON.stringify(saved), done: ev.bytes || 0, finished: Date.now()}));
            const what = row ? Words.summary(JSON.parse(row.filesJson), []) : saved.length + " items";
            remember({dir: "in", who: ev.sender || (row ? row.sender : ""), paths: saved, bytes: ev.bytes || 0, phase: "done",
                      title: saved.length === 1 ? ShellState.fileName(saved[0]) : what.charAt(0).toUpperCase() + what.slice(1)});
        } else if (ev.phase === "failed" || ev.phase === "cancelled") {
            updateIncoming(ev.id, () => ({phase: ev.phase, message: ev.message || "", finished: Date.now()}));
            countAsking();
        }
    }
    function outgoingTransfer(ev) {
        const i = indexOf(peers, "peerId", ev.peer);
        const name = i >= 0 ? peers.get(i).name : "";
        if (ev.phase === "asking" || ev.phase === "sending") {
            setPeer(ev.peer, {phase: ev.phase, transferId: ev.id, total: ev.total || 0});
            sending = {peerId: ev.peer, name: name, phase: ev.phase, done: 0, total: ev.total || 0, title: sending ? sending.title : stagedTitle()};
            return;
        }
        setPeer(ev.peer, {phase: ev.phase, message: ev.message || "", done: ev.phase === "done" && i >= 0 ? peers.get(i).total : 0});
        remember({dir: "out", who: name, title: sending ? sending.title : stagedTitle(), phase: ev.phase,
                  bytes: i >= 0 ? peers.get(i).total : 0, message: ev.message || ""});
        sending = null;
        if (!ShellState.panel || ShellState.panel !== "airdrop") {
            if (ev.phase === "done")
                ShellState.message("Sent to " + name, "success");
            else if (ev.phase === "declined")
                ShellState.message(name + " declined", "error");
            else if (ev.phase === "failed")
                ShellState.message("Couldn't send to " + name + (ev.message ? ": " + ev.message : ""), "error");
        }
    }
    function setPeer(peerId, fields) {
        const i = indexOf(peers, "peerId", peerId);
        if (i < 0)
            return;
        for (const key in fields)
            peers.setProperty(i, key, fields[key]);
    }
    function setTransfer(transferId, fields) {
        for (let i = 0; i < peers.count; i++)
            if (peers.get(i).transferId === transferId) {
                for (const key in fields)
                    peers.setProperty(i, key, fields[key]);
                if (sending && sending.peerId === peers.get(i).peerId)
                    sending = Object.assign({}, sending, fields);
            }
    }
    function updateIncoming(id, change) {
        const i = indexOf(incoming, "key", generation + ":" + id);
        if (i < 0)
            return;
        const fields = change(incoming.get(i));
        for (const key in fields)
            incoming.setProperty(i, key, fields[key]);
    }
    function remember(entry) {
        recent = [Object.assign({time: Date.now(), paths: [], bytes: 0, url: "", message: ""}, entry)].concat(recent).slice(0, 30);
    }
    function indexOf(model, field, value) {
        for (let i = 0; i < model.count; i++)
            if (model.get(i)[field] === value)
                return i;
        return -1;
    }

    // ---- processes ------------------------------------------------------------------------------------------------
    // `done` ends a session cleanly (the command gives Wi-Fi back first); a terminate signal does the same, later.
    function stopProcess(proc) {
        if (!proc.running)
            return;
        proc.write(JSON.stringify({done: true}) + "\n");
        proc.stopping = true;
        proc.escalate.restart();
    }
    component Session: Process {
        id: session
        property bool stopping: false
        // The command's last line on stderr, said when it stops without an error event.
        property string lastLine: ""
        property Timer escalate: Timer {
            interval: 30000
            onTriggered: if (session.running)
                session.signal(15)
        }
        stdinEnabled: true
        stderr: SplitParser {
            onRead: data => {
                if (data.trim())
                    session.lastLine = data.trim();
            }
        }
    }
    property Session receiver: Session {
        stdout: SplitParser {
            onRead: data => root.handle("rx", data)
        }
        onExited: code => {
            const asked = stopping;
            stopping = false;
            escalate.stop();
            root.receiverWifi = false;
            root.receiverState = "";
            root.incomingNow = null;
            // Questions of this process can't be answered any more.
            for (let i = 0; i < root.incoming.count; i++) {
                const row = root.incoming.get(i);
                if (row.generation === root.generation && ["asking", "accepted", "receiving"].indexOf(row.phase) >= 0) {
                    root.incoming.setProperty(i, "phase", "cancelled");
                    root.incoming.setProperty(i, "finished", Date.now());
                }
            }
            root.countAsking();
            if (!asked && root.mode !== "off" && root.startMode === root.mode) {
                if (!root.error)
                    root.fail("exit", lastLine || "AirDrop stopped (code " + code + ")");
                root.mode = "off";
            }
            if (root.pendingSearch)
                root.startSender();
            else
                root.startReceiver();
        }
    }
    property Session sender: Session {
        stdout: SplitParser {
            onRead: data => root.handle("tx", data)
        }
        onExited: code => {
            const asked = stopping;
            stopping = false;
            escalate.stop();
            root.senderWifi = false;
            if (root.sending) {
                root.setPeer(root.sending.peerId, {phase: "cancelled"});
                root.sending = null;
            }
            if (root.sendState !== "ended")
                root.sendState = asked || code === 0 ? "" : "ended";
            if (!asked && code !== 0 && code !== 4 && !root.error)
                root.fail("exit", lastLine || "AirDrop stopped (code " + code + ")");
            if (root.resumeMode) {
                root.mode = root.resumeMode;
                root.resumeMode = "";
            }
            root.startReceiver();
        }
    }

    // One-off commands (config, doctor), one at a time.
    property var queue: []
    property var current: null
    function run(args, onEvent, onDone) {
        if (!command)
            return;
        queue = queue.concat([{args: args, onEvent: onEvent, onDone: onDone}]);
        next();
    }
    function next() {
        if (current || !queue.length)
            return;
        current = queue[0];
        queue = queue.slice(1);
        tool.command = [command].concat(current.args);
        tool.running = true;
    }
    property Process tool: Process {
        stdout: SplitParser {
            onRead: data => {
                try {
                    const ev = JSON.parse(data);
                    if (root.current && root.current.onEvent)
                        root.current.onEvent(ev);
                } catch (e) {}
            }
        }
        onExited: code => {
            const done = root.current;
            root.current = null;
            if (done && done.onDone)
                done.onDone(code);
            root.next();
        }
    }
    function probe() {
        supported = false;
        if (!command)
            return;
        refreshConfig();
    }
    function refreshConfig() {
        run(["--json", "config", "show"], ev => {
            if (ev.event === "config") {
                root.config = ev;
                root.supported = true;
            }
        }, () => root.startup());
    }
    function checkComputer() {
        checking = true;
        run(["--json", "doctor"], ev => {
            if (ev.event === "doctor")
                root.doctor = ev;
        }, () => root.checking = false);
    }
    // Background comes back with the shell (it never takes Wi-Fi until an iPhone opens AirDrop).
    property bool started: false
    function startup() {
        if (started || !available || !ShellState.settings.version)
            return;
        started = true;
        if (ShellState.setting("airdropMode", "off") === "background")
            setMode("background", false);
    }
    property Connections settingsLoaded: Connections {
        target: ShellState
        function onSettingsChanged() {
            root.startup();
        }
    }
    Component.onCompleted: probe()

    property IpcHandler ipc: IpcHandler {
        target: "airdrop"
        function status(): string {
            return JSON.stringify({available: root.available, command: root.command, supported: root.supported, mode: root.mode, visibleLeft: root.visibleLeft,
                                   receiving: root.receiverState, searching: root.sendState, pending: root.countPending,
                                   wifiPaused: root.wifiPaused, error: root.error ? root.error.message : ""});
        }
        function mode(name: string): void {
            if (name === "toggle")
                root.toggleVisible();
            else
                root.setMode(name);
        }
        // Paths one per line: they are staged and the panel opens, ready to pick a device.
        function send(paths: string): void {
            if (!root.available)
                return;
            root.stage(paths.split("\n").filter(path => path));
            ShellState.open("airdrop");
        }
        function accept(): void {
            root.answerOldest("accept");
        }
        function decline(): void {
            root.answerOldest("decline");
        }
    }
}
