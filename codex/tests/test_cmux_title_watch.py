import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("watch", Path(__file__).parents[1] / "hooks/cmux_title_watch.py")
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)


class WatchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.prefix = Path(self.tmp.name) / "cmux_tab_title_test"
        self.path = Path(str(self.prefix) + ".watch.json")
        self.owner = Path(str(self.prefix) + ".session")
        self.cache = Path(str(self.prefix) + ".codex.json")
        self.path.write_text(json.dumps({"workspace": "w", "surface": "s",
                                         "cwd": "/home/workspace", "session_id": "old"}))
        self.owner.write_text("Codex:old\n")
        self.cache.write_text('{}')
        self.armed = set()
        self.title = "Topic | workspace"
        self.screen = "OpenAI Codex\nContext 100% left"
        self.calls = []

    def rpc(self, method, params):
        self.calls.append((method, params))
        if method == "surface.list":
            return {"surfaces": [{"id": "s", "title": self.title}]}
        if method == "surface.read_text":
            return {"text": self.screen}
        if method == "workspace.list":
            return {"workspaces": [{"id": "w", "index": 6, "title": "7:Codex Old"}]}
        return {}

    def tick(self):
        with patch.object(watch, "rpc", side_effect=self.rpc):
            watch.check(self.path, self.armed)

    def test_real_title_transition_clears_and_invalidates_old_summary(self):
        self.tick()
        self.title = "⠋ workspace"
        self.tick()
        self.assertEqual(self.owner.read_text(), "Codex:cleared\n")
        self.assertFalse(self.cache.exists())
        self.assertFalse(self.path.exists())
        self.assertIn(("workspace.rename", {"workspace_id": "w", "title": "7:Codex 待機"}), self.calls)

    def test_initial_blank_does_not_reset_running_first_turn(self):
        self.title = "workspace"
        self.tick()
        self.assertEqual(self.owner.read_text(), "Codex:old\n")

    def test_shell_title_is_not_a_clear(self):
        self.tick()
        self.title = "workspace"
        self.screen = "$ "
        self.tick()
        self.assertTrue(self.cache.exists())

    def test_new_session_is_not_reset_by_old_registration(self):
        self.tick()
        self.owner.write_text("Codex:new\n")
        self.title = "workspace"
        self.tick()
        self.assertEqual(self.owner.read_text(), "Codex:new\n")
        self.assertFalse(self.path.exists())
