import copy
import importlib.util
import pathlib
import unittest

s = importlib.util.spec_from_file_location(
    "duo", pathlib.Path(__file__).resolve().parents[1] / "scripts/duo.py"
)
d = importlib.util.module_from_spec(s)
s.loader.exec_module(d)


class ConfigTest(unittest.TestCase):
    def setUp(self):
        self.c = d.json.loads((d.ROOT / "config/example.json").read_text())

    def test_layout_reversed(self):
        self.c["layout"].reverse()
        a, b = d.validate(self.c, "macbook")
        self.assertEqual(b["name"], "mini")

    def test_reject_shell_and_unknown(self):
        for value in ("bad\nname", "$(id)", "a;id"):
            c = copy.deepcopy(self.c)
            c["nodes"][0]["host"] = value
            with self.assertRaises(ValueError):
                d.validate(c, "mini")

    def test_reject_unsupported_topology(self):
        self.c["nodes"].append(copy.deepcopy(self.c["nodes"][0]))
        with self.assertRaises(ValueError):
            d.validate(self.c, "mini")

    def test_bad_port(self):
        self.c["nodes"][0]["port"] = 0
        with self.assertRaises(ValueError):
            d.validate(self.c, "mini")


if __name__ == "__main__":
    unittest.main()
