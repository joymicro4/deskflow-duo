import importlib.util
import os
import pathlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "duo_keys", pathlib.Path(__file__).resolve().parents[1] / "scripts/duo.py"
)
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


class KeyLifecycleTest(unittest.TestCase):
    def test_private_generation_and_no_silent_replacement(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.object(d, "STATE", pathlib.Path(tmp) / "state"),
            patch("builtins.print"),
        ):
            d.keygen()
            key = d.shared_key()
            self.assertEqual(len(key), 32)
            self.assertEqual((d.STATE / "fwd.key").stat().st_mode & 0o777, 0o600)
            with self.assertRaises(FileExistsError):
                d.keygen()
            os.chmod(d.STATE / "fwd.key", 0o644)
            with self.assertRaises(ValueError):
                d.shared_key()

    def test_import_preserves_bytes_without_printing(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.object(d, "STATE", pathlib.Path(tmp) / "state"),
            patch("builtins.print") as output,
        ):
            source = pathlib.Path(tmp) / "input"
            source.write_bytes(bytes(range(32)))
            d.key_import(source)
            self.assertEqual(d.shared_key(), source.read_bytes())
            self.assertNotIn(str(bytes(range(32))), str(output.call_args))
            with self.assertRaises(ValueError):
                d.key_import(source)

    def test_pair_never_puts_key_in_arguments(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.object(d, "STATE", pathlib.Path(tmp)),
            patch("builtins.print"),
            patch.object(d, "run") as run,
        ):
            (d.STATE / "fwd.key").write_bytes(bytes(range(32)))
            os.chmod(d.STATE / "fwd.key", 0o600)
            d.pair("macbook.example")
            args, kwargs = run.call_args
            self.assertEqual(kwargs["input"], bytes(range(32)))
            self.assertIn("StrictHostKeyChecking=yes", args[0])
            self.assertNotIn(str(bytes(range(32))), str(args))
            with self.assertRaises(ValueError):
                d.pair("-oProxyCommand=bad")
