---
name: deskflow-duo
description: Configures physical-pointer takeover between two Macs using Deskflow Duo, with TLS trust, device filters and permission guidance. Use when a user asks to share an external mouse and MacBook trackpad across two Macs or diagnose automatic Deskflow direction switching.
---

# Deskflow Duo

Use the repository's `scripts/duo.py`; locate the repo from user context or ask for its path. Read its README before making changes. The skill directory is not a self-contained installer.

## Inspect first

1. Establish exactly two Macs, left/right order, stable addresses, Deskflow names, ports, macOS versions and which physical pointer should trigger each Mac.
2. Inspect existing Deskflow jobs/configuration read-only. Never overwrite a working setup. Explain the proposed local paths and changes before an authorized install.
3. Read `config/example.json`. Generate local configuration without publishing actual hostnames/addresses. More than two machines are not supported; do not invent arbitration.
4. Confirm Python 3, Xcode Command Line Tools and official Deskflow 1.27.0. Verify downloaded software against official assets and signatures. Do not install cloud services or change DNS/firewall automatically.

## Configure each Mac

- Use `external` for the Mac with USB/Bluetooth mouse; `builtin` for the MacBook trackpad. `keyDowns: 0` is the default: keyboard does not claim control.
- Run `python3 scripts/duo.py install --config CONFIG --node NAME --dry-run` first.
- After the user authorizes local setup, run `./scripts/install.sh CONFIG NAME`. Install does not start listeners. Backups are retained in the state directory.
- Run `fingerprint` on each Mac. Ask the user to independently verify the peer SHA-256, then `trust PEER_SHA256`. Never transport private PEM files or disable certificate checking.
- Run `permissions`. Guide the user to System Settings → Privacy & Security: Deskflow needs Accessibility and Input Monitoring; Duo Auto Switch needs Input Monitoring. The app is in `~/Library/Application Support/DeskflowDuo/Duo Auto Switch.app`. Use ⌘⇧G in the chooser if needed.
- **The user must click permission toggles personally.** Do not edit TCC databases, bypass prompts, or claim permissions were granted from a successful build alone.
- Run `start`; if permissions were changed, `stop` then `start`. Run `doctor` and inspect only relevant local log lines.

## Acceptance

1. Move external mouse while that Mac is follower. Confirm one takeover and cross-screen pointer/typing.
2. While the MacBook is follower, slide its built-in trackpad for at least half a second. Confirm `touch frames` takeover, then cross the configured edge.
3. Type on both keyboards without moving pointers. Confirm no takeover; explain client physical keyboards always type locally.
4. Check the 3-second guard, simultaneous physical use, peer disconnect, sleep/wake and manual `claim`.
5. Record what was actually observed. The reference implementation has confirmed physical touch capture but not yet a positive touch-triggered takeover test. Never present animation as hardware evidence.

## Recovery and boundaries

- `doctor` is read-only. `0xe00002c5` can mean Karabiner/device seizure; do not uninstall other software without explicit approval.
- MultitouchSupport is private; stationary contact may trigger and wake recovery is unverified. Offer manual `claim` or Universal Control if suitable.
- Local signing uses an identifier-only designated requirement, which can allow another app with the same ID to inherit permission. Explain this tradeoff; do not use unrelated company certificates. Production distribution requires proper signing/notarization.
- Stop before reinstalling config changes. `uninstall` stops/removes Duo LaunchAgents while retaining state, keys and backups; do not delete these or unrelated files without explicit approval.
- Keep real addresses, usernames, tokens, screenshots and logs out of public repos/issues. Redact before sharing.
