# Working on the redesign

## Layout
- `~/src/shale-dev` → private `TurcanS/shale-dev` (`origin`). Web sessions push here.
- `~/Documents/quickshell` → public `TurcanS/shale`. Only `scripts/dev promote` writes to it, on a new branch, never
  pushing.
- The installed shell (`~/.config/quickshell/shale`, `shale.service`) is never changed by any of this.

## A round
1. claude.ai/code → pick `TurcanS/shale-dev` → paste the stage prompt from `docs/PLAN.md`.
2. When it says it pushed:
   ```sh
   cd ~/src/shale-dev
   git fetch && git switch redesign && git pull --ff-only   # first time: git switch -c redesign origin/redesign
   scripts/dev run          # Ctrl+C to stop; the installed Shale comes back by itself
   ```
3. While it runs, your Shale shortcuts (Super+Space, Super+A, Print, …) drive the dev copy: `dev run` points them at
   it in the running Hyprland and back at the installed shell when it stops; no config file changes. `scripts/dev open
   control` and friends work too. Idle locking still goes through the installed command, so it uses hyprlock then.
4. If something broke: `scripts/dev errors` → paste that, plus a screenshot, as the first message of the next session.
5. Optional checks: `scripts/dev lint`, `scripts/dev tests` (borrows the local tests from the public checkout).

The dev copy reads and writes the same settings file as the installed shell. `dev run` saves a copy first
(`~/.config/shale/config.json.dev-*`); `scripts/dev restore-config` puts the newest one back.

## Moving a finished stage to the public repo
```sh
scripts/dev promote redesign-stage-3 "Float the bar and redraw its items"
```
This makes a worktree next to the public checkout with one commit containing the shell changes only (no
`docs/design`, `docs/PLAN.md`, `docs/DEV.md`, `CLAUDE.md`, `.claude`, `scripts/dev`). The public repo's hooks check
it. Review it, then merge or push it yourself.

## Spending less
- One stage per session; start a new session for the next stage instead of continuing a long one.
- The first message should be the stage prompt only; the session reads CLAUDE.md and the docs itself.
- When reporting a bug, paste `dev errors` and name the panel; don't paste whole files.
- Small fixes (one colour, one spacing value) are cheaper to make yourself in the file than in a session.
