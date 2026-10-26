# Deskflow Duo

Use `python3 -m unittest discover -s tests`, `bash -n scripts/*.sh`, and `./scripts/build.sh` on macOS. Video checks: `cd video && npm ci && npm run lint`.

Never test install/start against a user's live setup. Use temporary `DUO_STATE_DIR` and `DUO_LAUNCH_DIR`; do not bootstrap LaunchAgents in tests. Never commit local config, PEM/private keys or environment files.

Default takeover is pointer-only (`keyDowns=0`). Exactly two Macs; reject unsupported topology. Physical touch capture is observed but positive touch-triggered takeover remains pending hardware acceptance. Keep this distinction in product claims.
