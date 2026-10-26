#!/usr/bin/env python3
"""Deskflow Duo lifecycle. No shell-sourced configuration or remote execution."""

import argparse
import contextlib
import fcntl
import datetime
import json
import os
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
STATE = pathlib.Path(
    os.environ.get(
        "DUO_STATE_DIR",
        str(pathlib.Path.home() / "Library/Application Support/DeskflowDuo"),
    )
)
LA = pathlib.Path(
    os.environ.get("DUO_LAUNCH_DIR", str(pathlib.Path.home() / "Library/LaunchAgents"))
)
PREFIX = "ai.joymicro.deskflow-duo."


def run(args, **kw):
    return subprocess.run([str(x) for x in args], check=True, **kw)


def validate(c, me):
    nodes = c["nodes"]
    names = [n["name"] for n in nodes]
    if len(nodes) != 2:
        raise ValueError(
            "v0.1 supports exactly two Macs; multi-node arbitration is not implemented"
        )
    if len(set(names)) != 2 or me not in names:
        raise ValueError("unique node names and a valid --node are required")
    if sorted(c["layout"]) != sorted(names) or c["preferred"] not in names:
        raise ValueError("layout/preferred must reference nodes")
    for n in nodes:
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,40}", n["name"]):
            raise ValueError("invalid node name")
        if not re.fullmatch(r"[A-Za-z0-9.:-]+", n["host"]):
            raise ValueError("invalid host")
        if type(n["port"]) is not int or not 1024 <= n["port"] <= 65535:
            raise ValueError("invalid port")
        if n["input"] not in ("builtin", "external"):
            raise ValueError("input must be builtin/external")
    for k in ("pointerReports", "touchFrames"):
        if type(c.get(k, 6)) is not int or not 1 <= c.get(k, 6) <= 1000:
            raise ValueError("invalid input threshold")
    if type(c.get("keyDowns", 0)) is not int or not 0 <= c.get("keyDowns", 0) <= 1000:
        raise ValueError("invalid key threshold")
    if not isinstance(c.get("deviceProduct", ""), str):
        raise ValueError("invalid product filter")
    fwd = c.get("keyboardForwarding", {"mode": "off"})
    if fwd.get("mode") not in ("off", "observe", "on"):
        raise ValueError("keyboardForwarding.mode must be off/observe/on")
    if fwd["mode"] != "off":
        if fwd.get("listener") not in names:
            raise ValueError("keyboard forwarding listener must reference a node")
        port = fwd.get("port")
        if (
            type(port) is not int
            or not 1024 <= port <= 65535
            or port in [n["port"] for n in nodes]
        ):
            raise ValueError("keyboard forwarding needs a separate valid TCP port")
    return next(n for n in nodes if n["name"] == me), next(
        n for n in nodes if n["name"] != me
    )


def backup(p):
    if p.exists():
        dest = (
            STATE
            / "backups"
            / datetime.datetime.now().strftime("%Y%m%dT%H%M%S%f")
            / p.name
        )
        dest.parent.mkdir(parents=True, exist_ok=True)
        if p.is_dir():
            shutil.copytree(p, dest)
        else:
            shutil.copy2(p, dest)


def write(p, text):
    p.parent.mkdir(parents=True, exist_ok=True)
    backup(p)
    p.write_text(text)


def label(role):
    return f"gui/{os.getuid()}/{PREFIX}{role}"


def ctl(action, role):
    return subprocess.run(
        ["launchctl", action, label(role)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode


def config():
    return json.loads((STATE / "config.json").read_text())


@contextlib.contextmanager
def role_lock():
    """Serialize claim/failover across the helper and supervisor processes."""
    with (STATE / "role.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def claim_locked():
    flag = STATE / "follower"
    if flag.exists():
        # Publish the grace timestamp before exposing the new master role.
        pending = STATE / "took-control.pending"
        pending.write_text(str(time.time()))
        pending.replace(STATE / "took-control")
        flag.unlink()
        subprocess.run(
            ["launchctl", "kill", "SIGTERM", label("client")], capture_output=True
        )


def claim():
    with role_lock():
        claim_locked()


def reconcile(sc, cc, preferred):
    # Socket observations may predate a claim. Read role + timestamp under the
    # same lock as claim_locked(), so an old observation cannot erase its grace.
    with role_lock():
        flag = STATE / "follower"
        if flag.exists():
            if preferred and sc and cc:
                claim_locked()
            elif not cc:
                ctl("kickstart", "client")
        else:
            subprocess.run(
                ["launchctl", "kill", "SIGTERM", label("client")], capture_output=True
            )
            took = (
                float((STATE / "took-control").read_text())
                if (STATE / "took-control").exists()
                else 0
            )
            if not sc and time.time() - took > 5:
                flag.touch()
                ctl("kickstart", "client")


def connections(port, server):
    # Scope socket inspection to this managed Deskflow instance.
    role = "server" if server else "client"
    status = subprocess.run(
        ["launchctl", "print", label(role)], capture_output=True, text=True
    )
    pid = re.search(r"\bpid = (\d+)", status.stdout)
    if not pid:
        return False
    p = subprocess.run(
        [
            "/usr/sbin/lsof",
            "-nP",
            "-a",
            "-p",
            pid.group(1),
            "-iTCP",
            "-sTCP:ESTABLISHED",
        ],
        capture_output=True,
        text=True,
    )
    pat = rf":{port}->" if server else rf"->[^\s]*:{port}(?:\s|$)"
    return bool(re.search(pat, p.stdout))


def supervise():
    c = config()
    me, peer = validate(c, c["localNode"])
    while True:
        sc = connections(me["port"], True)
        cc = connections(peer["port"], False)
        reconcile(sc, cc, c["preferred"] == me["name"])
        time.sleep(0.5)


def install(a):
    c = json.loads(pathlib.Path(a.config).read_text())
    me, peer = validate(c, a.node)
    if a.dry_run:
        print(
            json.dumps(
                {
                    "node": me["name"],
                    "peer": peer["name"],
                    "state": str(STATE),
                    "layout": c["layout"],
                    "launchAgents": 4,
                    "activation": "explicit start after TLS trust and permissions",
                },
                indent=2,
            )
        )
        return
    if sys.platform != "darwin":
        raise ValueError("macOS is required")
    if not pathlib.Path(a.core).is_file():
        raise ValueError("Install Deskflow first; see README")
    a.core = str(pathlib.Path(a.core).resolve())
    version = subprocess.run([a.core, "--version"], capture_output=True, text=True)
    if "1.27.0" not in version.stdout + version.stderr:
        raise ValueError(
            "Deskflow 1.27.0 required; other settings formats are unverified"
        )
    for role in ("server", "client", "supervisor", "auto"):
        if (
            subprocess.run(
                ["launchctl", "print", label(role)], capture_output=True
            ).returncode
            == 0
        ):
            raise ValueError("stop existing Duo jobs before reinstalling")
    app = ROOT / "build/Duo Auto Switch.app"
    if not app.exists():
        run([ROOT / "scripts/build.sh"])
    STATE.mkdir(parents=True, exist_ok=True)
    os.chmod(STATE, 0o700)
    c["localNode"] = a.node
    c["core"] = str(pathlib.Path(a.core).resolve())
    write(STATE / "config.json", json.dumps(c, indent=2))
    for name in ("scripts", "app"):
        dest = STATE / ("scripts" if name == "scripts" else "Duo Auto Switch.app")
        backup(dest)
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(ROOT / "scripts" if name == "scripts" else app, dest)
    manual = STATE / "Duo Take Control.app"
    backup(manual)
    (manual / "Contents/MacOS").mkdir(parents=True, exist_ok=True)
    (manual / "Contents/Info.plist").write_bytes(
        plistlib.dumps(
            dict(
                CFBundleIdentifier="ai.joymicro.deskflow-duo.claim",
                CFBundleName="Duo Take Control",
                CFBundleExecutable="claim",
                CFBundlePackageType="APPL",
                LSUIElement=True,
            )
        )
    )
    launcher = manual / "Contents/MacOS/claim"
    launcher.write_text(
        "#!/bin/sh\nexport DUO_STATE_DIR="
        + shquote(str(STATE))
        + "\nexec "
        + shquote(sys.executable)
        + " "
        + shquote(str(STATE / "scripts/duo.py"))
        + " claim\n"
    )
    launcher.chmod(0o700)
    run(
        ["codesign", "--force", "--sign", "-", manual],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    write(
        STATE / "take-control.sh",
        "#!/bin/sh\nexport DUO_STATE_DIR="
        + shquote(str(STATE))
        + "\nexec "
        + shquote(sys.executable)
        + " "
        + shquote(str(STATE / "scripts/duo.py"))
        + " claim\n",
    )
    (STATE / "take-control.sh").chmod(0o700)
    cert = STATE / "tls/deskflow.pem"
    cert.parent.mkdir(exist_ok=True)
    if not cert.exists():
        import tempfile

        with tempfile.TemporaryDirectory() as t:
            run(
                [
                    "/usr/bin/openssl",
                    "req",
                    "-x509",
                    "-nodes",
                    "-days",
                    "825",
                    "-newkey",
                    "rsa:2048",
                    "-subj",
                    "/CN=DeskflowDuo",
                    "-keyout",
                    t + "/key",
                    "-out",
                    t + "/cert",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            cert.write_bytes(
                pathlib.Path(t + "/cert").read_bytes()
                + pathlib.Path(t + "/key").read_bytes()
            )
            cert.chmod(0o600)
    left, right = c["layout"]
    write(
        STATE / "server/server.conf",
        f"section: links\n\t{left}:\n\t\tright = {right}\n\t{right}:\n\t\tleft = {left}\nend\n",
    )

    def common(port):
        return f"[core]\ncomputerName={a.node}\nport={port}\npreventSleep=false\n[log]\nlevel=INFO\ntoFile=false\n[security]\ntlsEnabled=true\ncheckPeerFingerprints=true\ncertificate={cert}\n[gui]\nenableUpdateCheck=false\n"

    write(
        STATE / "server/Deskflow.conf",
        common(me["port"])
        + f"[server]\nexternalConfig=true\nexternalConfigFile={STATE}/server/server.conf\n"
        + "".join(f"[computer_{n}]\nname={n}\n" for n in c["layout"]),
    )
    write(
        STATE / "client/Deskflow.conf",
        common(peer["port"]) + f"[client]\nremoteHost={peer['host']}\n",
    )
    if me["name"] != c["preferred"]:
        (STATE / "follower").touch()
    else:
        (STATE / "took-control").write_text(str(time.time()))
    args = {
        "server": [
            a.core,
            "server",
            "--new-instance",
            "-s",
            str(STATE / "server/Deskflow.conf"),
        ],
        "client": [
            a.core,
            "client",
            "--new-instance",
            "-s",
            str(STATE / "client/Deskflow.conf"),
        ],
        "supervisor": [sys.executable, str(STATE / "scripts/duo.py"), "supervise"],
        "auto": [
            str(STATE / "Duo Auto Switch.app/Contents/MacOS/duo-auto"),
            me["input"],
            f"keys={c.get('keyDowns', 0)}",
            f"ptr={c.get('pointerReports', 6)}",
            f"touch={c.get('touchFrames', 25)}",
            f"product={c.get('deviceProduct', '')}",
        ],
    }
    fwd = c.get("keyboardForwarding", {"mode": "off"})
    args["auto"].append("kbfwd=" + fwd["mode"])
    if fwd["mode"] != "off":
        listener = next(n for n in c["nodes"] if n["name"] == fwd["listener"])
        channel = (
            f"listen:{fwd['port']}"
            if me["name"] == listener["name"]
            else f"connect:{listener['host']}:{fwd['port']}"
        )
        args["auto"].append("fwd=" + channel)
    LA.mkdir(parents=True, exist_ok=True)
    (STATE / "logs").mkdir(exist_ok=True)
    for role, argv in args.items():
        p = LA / f"{PREFIX}{role}.plist"
        backup(p)
        keep = (
            {"PathState": {str(STATE / "follower"): True}} if role == "client" else True
        )
        p.write_bytes(
            plistlib.dumps(
                dict(
                    Label=PREFIX + role,
                    ProgramArguments=argv,
                    EnvironmentVariables={"DUO_STATE_DIR": str(STATE)},
                    KeepAlive=keep,
                    RunAtLoad=role != "client" or (STATE / "follower").exists(),
                    ThrottleInterval=5,
                    ProcessType="Interactive",
                    StandardOutPath=str(STATE / f"logs/{role}.log"),
                    StandardErrorPath=str(STATE / f"logs/{role}.log"),
                )
            )
        )
    print(
        "Installed, not started. Exchange TLS fingerprints, grant permissions, then run start."
    )


def shquote(s):
    import shlex

    return shlex.quote(s)


def trust(fp):
    fp = fp.replace(":", "").lower()
    if not re.fullmatch("[0-9a-f]{64}", fp):
        raise ValueError("expected a SHA-256 certificate fingerprint")
    # Deskflow fingerprint DB format: version:algorithm:lowercase hex digest.
    line = "v2:sha256:" + fp + "\n"
    for role in ("server", "client"):
        p = STATE / role / "tls/trusted-servers"
        write(p, line)
        write(STATE / role / "tls/trusted-clients", line)
    print("Peer fingerprint stored. Verify it out of band on the other Mac.")


def shared_key():
    p = STATE / "fwd.key"
    if not p.exists() or p.stat().st_mode & 0o777 != 0o600 or p.stat().st_size != 32:
        raise ValueError(
            "keyboard forwarding requires a 32-byte fwd.key with mode 0600; use keygen or key-import"
        )
    return p.read_bytes()


def keygen():
    import secrets

    STATE.mkdir(parents=True, exist_ok=True)
    os.chmod(STATE, 0o700)
    fd = os.open(STATE / "fwd.key", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(secrets.token_bytes(32))
    print(
        "Shared key generated privately. Transfer via an authenticated encrypted channel, never paste or commit it."
    )


def key_import(path):
    data = sys.stdin.buffer.read(33) if path == "-" else pathlib.Path(path).read_bytes()
    if len(data) != 32:
        raise ValueError("expected a 32-byte binary key file")
    STATE.mkdir(parents=True, exist_ok=True)
    os.chmod(STATE, 0o700)
    p = STATE / "fwd.key"
    if p.exists():
        raise ValueError(
            "a key already exists; stop both peers and back it up before explicitly rotating"
        )
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    print(
        "Shared key imported privately. Compare key-fingerprint on both Macs before starting."
    )


def pair(target):
    # Send the key only on ssh stdin, never through argv, logs or a local file.
    if target.startswith("-") or not re.fullmatch(
        r"(?:[A-Za-z0-9_.-]+@)?[A-Za-z0-9_.:-]+", target
    ):
        raise ValueError("invalid SSH destination")
    key = shared_key()
    remote = 'python3 "$HOME/Library/Application Support/DeskflowDuo/scripts/duo.py"'
    run(
        [
            "ssh",
            "-o",
            "StrictHostKeyChecking=yes",
            "--",
            target,
            remote + " key-import - && " + remote + " key-fingerprint",
        ],
        input=key,
    )
    import hashlib

    print("Local shared key SHA-256: " + hashlib.sha256(key).hexdigest())
    print(
        "Verify that the local and remote fingerprints match. No key was printed or stored in a temporary file."
    )


def doctor():
    problems = []
    if sys.platform != "darwin":
        problems.append("macOS required")
    if not shutil.which("swiftc"):
        problems.append("Xcode Command Line Tools missing: xcode-select --install")
    if not shutil.which("python3"):
        problems.append("Python 3 missing")
    if not (STATE / "config.json").exists():
        problems.append("not installed")
    else:
        c = config()
        validate(c, c["localNode"])
        if not pathlib.Path(c["core"]).exists():
            problems.append("Deskflow core missing")
        cert = STATE / "tls/deskflow.pem"
        if not cert.exists():
            problems.append("TLS certificate missing")
        elif subprocess.run(
            ["/usr/bin/openssl", "x509", "-checkend", "0", "-noout", "-in", str(cert)],
            capture_output=True,
        ).returncode:
            problems.append("TLS certificate expired or invalid")
        for role in ("server", "client"):
            if not (STATE / role / "tls/trusted-servers").exists():
                problems.append(role + ": TLS peer trust missing")
        for role in ("server", "client", "supervisor", "auto"):
            if not (LA / f"{PREFIX}{role}.plist").exists():
                problems.append(role + ": LaunchAgent missing")
        fwd = c.get("keyboardForwarding", {"mode": "off"})
        if fwd["mode"] != "off":
            try:
                shared_key()
            except ValueError as error:
                problems.append(str(error))
        logs = STATE / "logs/auto.log"
        if logs.exists():
            tail = logs.read_text(errors="replace")[-12000:]
            if "input-monitoring=granted" not in tail:
                problems.append("Input Monitoring not confirmed; open permissions")
            if fwd["mode"] == "on":
                if (
                    "accessibility=true" not in tail
                    or "kbfwd tap ok (intercept)" not in tail
                ):
                    problems.append(
                        "Duo Accessibility/event tap not confirmed; grant both permissions"
                    )
                if "fwd authenticated pong received" not in tail:
                    problems.append(
                        "keyboard channel not authenticated; check shared key, port and peer permissions"
                    )
            if "0xe00002c5" in tail:
                problems.append(
                    "HID device seized; inspect Karabiner, do not uninstall automatically"
                )
            if "WATCH:" not in tail:
                problems.append("no accepted HID device; review device filter")
            if (
                any(
                    n["input"] == "builtin" and n["name"] == c["localNode"]
                    for n in c["nodes"]
                )
                and "WATCH: builtin trackpad" not in tail
            ):
                problems.append("Multitouch unavailable; keyboard/manual fallback")
        else:
            problems.append("no input log yet; start and complete permission checks")
    print(
        "\n".join("WARN " + p for p in problems)
        if problems
        else "OK configuration checks passed; verify Accessibility and real cross-screen input manually"
    )
    return 1 if problems else 0


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)
    i = sub.add_parser("install")
    i.add_argument("--config", required=True)
    i.add_argument("--node", required=True)
    i.add_argument(
        "--core", default="/Applications/Deskflow.app/Contents/MacOS/deskflow-core"
    )
    i.add_argument("--dry-run", action="store_true")
    for cmd in (
        "start",
        "stop",
        "uninstall",
        "doctor",
        "claim",
        "supervise",
        "fingerprint",
        "permissions",
        "keygen",
        "key-fingerprint",
    ):
        sub.add_parser(cmd)
    sub.add_parser("trust").add_argument("fingerprint")
    sub.add_parser("key-import").add_argument("file")
    sub.add_parser("pair").add_argument("--ssh", required=True)
    a = p.parse_args()
    if a.command == "install":
        install(a)
    elif a.command == "doctor":
        return doctor()
    elif a.command == "claim":
        claim()
    elif a.command == "supervise":
        supervise()
    elif a.command == "trust":
        trust(a.fingerprint)
    elif a.command == "pair":
        pair(a.ssh)
    elif a.command == "keygen":
        keygen()
    elif a.command == "key-import":
        key_import(a.file)
    elif a.command == "key-fingerprint":
        import hashlib

        print("Shared key SHA-256: " + hashlib.sha256(shared_key()).hexdigest())
    elif a.command == "fingerprint":
        run(
            [
                "/usr/bin/openssl",
                "x509",
                "-in",
                STATE / "tls/deskflow.pem",
                "-noout",
                "-fingerprint",
                "-sha256",
            ]
        )
    elif a.command == "permissions":
        print(
            "System Settings > Privacy & Security: Input Monitoring + Accessibility = Duo Auto Switch and Deskflow. Quit/restart after granting. Never modify TCC database."
        )
        run(
            [
                "open",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            ]
        )
    elif a.command in ("start", "stop", "uninstall"):
        if a.command == "start":
            if config().get("keyboardForwarding", {"mode": "off"})["mode"] != "off":
                shared_key()
            for role in ("server", "client"):
                if (
                    not (STATE / role / "tls/trusted-servers").exists()
                    or not (STATE / role / "tls/trusted-clients").exists()
                ):
                    raise ValueError("verify peer fingerprint and run trust first")
            for role in ("server", "client", "supervisor", "auto"):
                pth = LA / f"{PREFIX}{role}.plist"
                if not pth.exists():
                    raise ValueError("install first")
                if (
                    subprocess.run(
                        ["launchctl", "print", label(role)], capture_output=True
                    ).returncode
                    != 0
                ):
                    run(["launchctl", "bootstrap", f"gui/{os.getuid()}", pth])
        else:
            for role in ("auto", "supervisor", "client", "server"):
                ctl("bootout", role)
                if a.command == "uninstall":
                    pth = LA / f"{PREFIX}{role}.plist"
                    backup(pth)
                    pth.unlink(missing_ok=True)
            print(
                "Stopped. State, TLS keys and backups retained for recovery."
                if a.command == "uninstall"
                else "Stopped."
            )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as e:
        print("ERROR " + str(e), file=sys.stderr)
        sys.exit(2)
