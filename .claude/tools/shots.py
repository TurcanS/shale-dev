#!/usr/bin/env python3
"""Screenshots of every panel in the running shell, to compare with docs/design/previews.

Usage: .claude/tools/shots.py OUT_DIR [NAME ...]

Opens each panel (and each Control page) through the shell's IPC, captures the focused output with grim, closes the
panel again, then prints the shell's QML warnings and errors from the last ten minutes. NAME limits the run to some
panels, e.g. `control wifi settings`. Capture is only opened, never triggered.
"""
import json
import pathlib
import subprocess
import sys
import time

CHECKOUT = pathlib.Path(__file__).resolve().parents[2]
PANELS = ["launcher", "control", "notifications", "calendar", "clipboard", "overview", "capture", "settings", "power",
          "wallpaper", "activity", "system"]
PAGES = ["wifi", "bluetooth", "audio", "media", "focus", "power", "update"]
# Wayland noise that says nothing about the shell's own QML.
NOISE = ("qt.qpa.wayland.textinput",)


def ipc(*args):
    return subprocess.run(["quickshell", "ipc", "-p", str(CHECKOUT), "call", "shell", *args], capture_output=True,
                          text=True)


def focused_output():
    monitors = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True).stdout)
    return next((m["name"] for m in monitors if m.get("focused")), monitors[0]["name"])


def main():
    if len(sys.argv) < 2:
        sys.exit((__doc__ or "").strip())
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    wanted = set(sys.argv[2:])
    output = focused_output()
    shots = [(name, ("toggle", name)) for name in PANELS] + [("control-" + page, ("page", page)) for page in PAGES]
    for name, call in shots:
        if wanted and name not in wanted and name.removeprefix("control-") not in wanted:
            continue
        ipc("close")
        time.sleep(0.4)
        result = ipc(*call)
        # Long enough for the entrance and the first data to arrive.
        time.sleep(1.3)
        path = out / f"{name}.png"
        subprocess.run(["grim", "-o", output, str(path)], check=True)
        print(path if result.returncode == 0 else f"{path} (ipc: {result.stderr.strip()})")
    ipc("close")
    log = subprocess.run(["journalctl", "--user", "-u", "shale.service", "--since", "-10 min", "--no-pager", "-o", "cat"],
                         capture_output=True, text=True).stdout.splitlines()
    problems = [line for line in log if ("WARN" in line or "ERROR" in line or ".qml" in line)
                and not any(noise in line for noise in NOISE)]
    print("\nShell warnings and errors in the last 10 minutes:" if problems else "\nNo shell warnings or errors.")
    for line in problems[-40:]:
        print("  " + line.strip())


if __name__ == "__main__":
    main()
