import importlib.util
import pathlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "duo_roles", pathlib.Path(__file__).resolve().parents[1] / "scripts/duo.py"
)
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


class RolesTest(unittest.TestCase):
    def test_stale_socket_observation_cannot_undo_claim(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.object(d, "STATE", pathlib.Path(tmp)),
            patch.object(d.subprocess, "run"),
            patch.object(d.time, "time", return_value=100),
        ):
            (d.STATE / "follower").touch()
            (d.STATE / "took-control").write_text("0")
            d.claim()
            d.reconcile(False, False, False)
            self.assertFalse((d.STATE / "follower").exists())
            self.assertEqual((d.STATE / "took-control").read_text(), "100")
            self.assertFalse((d.STATE / "took-control.pending").exists())
            with patch.object(d.time, "time", return_value=106):
                d.reconcile(False, False, False)
            self.assertTrue((d.STATE / "follower").exists())
