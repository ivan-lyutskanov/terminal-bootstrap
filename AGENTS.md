# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

## Design invariants

- **No version pinning anywhere** (captain's explicit requirement). The sole exception is a
  version *floor* for herdr: its bundled opencode skill first shipped in herdr 0.8.0, so the
  installer upgrades herdr to that floor only when needed. A floor, not a pin -- no upper
  bound. See the floor logic in `bootstrap.sh` (step 4).
- **Install on fresh machines AND converge old-generation installs.** Every run is
  idempotent. Convergence may only touch lines the installer can prove it wrote itself
  (byte-identical known strings); an existing user config is never overwritten wholesale.
  See the rc + atuin handling in `bootstrap.sh` (steps 5-6).
- **The herdr skill for opencode is a managed file, not a symlink.** It is fetched from the
  GitHub tag matching the installed herdr so skill and binary never drift; a Cellar symlink
  dangles on `brew cleanup`. See `bootstrap.sh` (step 4).

## Layout

- `bootstrap.sh` is the installer (numbered steps 1-7 plus a summary); `shell/init.sh` is
  the single sourced shell-config file; `Brewfile` lists the tools; `docs/GUIDE.md` is the
  user guide.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
