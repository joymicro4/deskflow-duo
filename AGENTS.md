# Deskflow Duo

Use `./scripts/test-protocol.sh`, `python3 -m unittest discover -s tests`, `bash -n scripts/*.sh`, and `./scripts/build.sh` on macOS. Video checks: `cd video && npm ci && npm run lint`.

Never test install/start against a user's live setup. Use temporary `DUO_STATE_DIR` and `DUO_LAUNCH_DIR`; do not bootstrap LaunchAgents in tests. Never commit local config, PEM/private keys or environment files.

Default takeover is pointer-only (`keyDowns=0`). Exactly two Macs; reject unsupported topology. The user confirmed the original environment’s four controller/cursor combinations. The generalized build uses a session-nonce protocol incompatible with the prototype and still requires its own hardware acceptance. Preserve this distinction. Test without installing listeners or hooking real keyboards.
