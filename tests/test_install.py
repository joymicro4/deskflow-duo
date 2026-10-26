"""Exercise artifact generation in isolation, without loading jobs or opening HID."""

import os
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


@unittest.skipUnless(
    sys.platform == "darwin" and (ROOT / "build/Duo Auto Switch.app").exists(),
    "requires local macOS build",
)
class InstallTest(unittest.TestCase):
    def test_artifacts_and_backup(self):
        with tempfile.TemporaryDirectory(prefix="duo-isolated-") as t:
            state = pathlib.Path(t) / "state"
            agents = pathlib.Path(t) / "agents"
            env = dict(os.environ, DUO_STATE_DIR=str(state), DUO_LAUNCH_DIR=str(agents))
            core = pathlib.Path(t) / "deskflow-core"
            core.write_text("#!/bin/sh\necho v1.27.0\n")
            core.chmod(0o700)

            def cli(*args):
                return subprocess.run(
                    [sys.executable, str(ROOT / "scripts/duo.py"), *args],
                    env=env,
                    check=True,
                    capture_output=True,
                    text=True,
                )

            args = (
                "install",
                "--config",
                str(ROOT / "config/example.json"),
                "--node",
                "macbook",
                "--core",
                str(core),
            )
            cli(*args)
            cli("trust", "ab" * 32)
            self.assertEqual(
                (state / "client/tls/trusted-servers").read_text(),
                "v2:sha256:" + "ab" * 32 + "\n",
            )
            self.assertEqual((state / "tls/deskflow.pem").stat().st_mode & 0o777, 0o600)
            plists = list(agents.glob("*.plist"))
            self.assertEqual(len(plists), 4)
            auto = plistlib.loads(
                (agents / "ai.joymicro.deskflow-duo.auto.plist").read_bytes()
            )
            self.assertIn("keys=0", auto["ProgramArguments"])
            for p in plists:
                self.assertEqual(
                    plistlib.loads(p.read_bytes())["EnvironmentVariables"][
                        "DUO_STATE_DIR"
                    ],
                    str(state),
                )
            self.assertTrue(
                (state / "Duo Take Control.app/Contents/MacOS/claim").exists()
            )
            cli(*args)
            self.assertTrue(list((state / "backups").iterdir()))
            # Read-only doctor must detect missing runtime logs rather than claim success.
            p = subprocess.run(
                [sys.executable, str(ROOT / "scripts/duo.py"), "doctor"],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(p.returncode, 1)
            self.assertIn("no input log", p.stdout)
