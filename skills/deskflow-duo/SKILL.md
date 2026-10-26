---
name: deskflow-duo
description: Configures two Macs so a Mac mini's external keyboard/mouse and a MacBook's built-in keyboard/trackpad can control both, without a shared Apple Account. Use when setting up Deskflow Duo, encrypted keyboard forwarding, permissions, pairing or automatic takeover.
---

# Deskflow Duo v0.2

Locate the repository from user context; read README and CHANGELOG. This skill uses the repository scripts and is not a self-contained installer.

## Discover and prepare

1. Confirm exactly two Macs, their left/right order, stable addresses, Deskflow names/ports, macOS versions and physical pointer sources. Default scenario: mini + macbook; config/air-pro.json is another example.
2. Inspect existing jobs/configuration read-only. Never replace a working setup or uninstall Karabiner without user authorization. Explain paths and changes before installing.
3. Confirm official Deskflow 1.27.0, Python 3 and Command Line Tools. Do not change DNS or disable a firewall. Different Apple accounts are supported; organizational policies and device permissions still apply.
4. Generate local JSON from config/example.json. Exactly two nodes; select one keyboard-channel listener with an independent port. Do not invent multi-node arbitration.

## Install and pair

- Run `python3 scripts/duo.py install --config CONFIG --node NODE --dry-run`, then the authorized `./scripts/install.sh CONFIG NODE` on each Mac. Installation does not start listeners. Keep keys=0: pointer claims control, keyboard does not.
- Exchange public `fingerprint` output over a trusted channel, verify it, then run `trust PEER_CERT_SHA256` on each. Never transmit private certificate PEMs or disable verification.
- Run `keygen` on one Mac. Transfer its state-directory fwd.key privately via an already authenticated encrypted file channel, use `key-import PRIVATE_FILE` on the other, then compare `key-fingerprint` values. The binary key is exactly 32 bytes and mode 0600. Never print it, use clipboard/chat, include it in an argv, or commit it. Do not replace an existing key silently.
- Both ends must use the same version; the session-nonce protocol is incompatible with the earlier running prototype.
- Run `permissions`. Guide the user to grant **Input Monitoring and Accessibility to both Deskflow and Duo Auto Switch on both Macs**. Duo is at `~/Library/Application Support/DeskflowDuo/Duo Auto Switch.app`; use ⌘⇧G in the chooser.
- Permission toggles must be clicked by the user. Never modify TCC databases or claim a successful build proves authorization.
- Run `start`; stop/start after permission changes. Run `doctor`, inspect relevant status/count logs, and verify authenticated pong and event tap. Logs contain no typed characters.

## Acceptance: four combinations

With mini as controller, put cursor first on mini and then MacBook; type with each keyboard. Repeat with MacBook as controller. All four rows should route **both keyboards to the cursor's Mac**. This reference behavior was confirmed by the user; do not claim a new generalized install has been tested without doing it.

Check physical mouse/trackpad takeover, 3-second guard, Command shortcuts/keyUp flags, simultaneous use, disconnect while holding a modifier, timeout, sleep/wake and manual claim. Standalone protocol tests cover 13-byte messages, cryptographic validation and replay without hooking real keyboards.

## Emergency and recovery

- Physical **⌃⌥⌘K** toggles forwarding with a notification. State persists in kbfwd-disabled across restarts/reinstalls. Do not use double-Esc or clear the emergency state automatically.
- Channel failure/permission failure disables interception and allows local typing. A few queued events may be lost during abrupt failure. Secure Input (password fields) may prevent capture; never bypass it. Input method/layout follows the controller.
- `claim` or Duo Take Control.app manually requests control. `stop`/`uninstall` affect only Duo jobs; state/keys/backups remain.
- `0xe00002c5` may mean device seizure. Private MultitouchSupport and wake recovery need per-version tests; stationary touch counts. Offer manual fallback.
- Identifier-only local signing reduces reauthorization churn but permits same-ID permission inheritance. Explain it; use no unrelated signing identity. Formal distribution needs certificate-bound signing/notarization.
- Keep addresses, hostnames, account identifiers, keys, logs and real screenshots private. Never send credentials to a colleague or public issue.
