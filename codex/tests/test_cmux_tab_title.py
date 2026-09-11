import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("hook", Path(__file__).parents[1] / "hooks/cmux_tab_title.py")
hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hook)


class TitleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "rollout.jsonl"
        records = [
            {"type": "session_meta", "payload": {"source": "cli"}},
            {"type": "response_item", "payload": {"type": "message", "role": "user", "content": [{"type": "input_text", "text": "# AGENTS.md instructions hidden"}]}},
            {"type": "response_item", "payload": {"type": "message", "role": "user", "content": [{"type": "input_text", "text": "cmuxのタブに要約を表示して"}]}},
            {"type": "response_item", "payload": {"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": "応答本文" * 20}]}},
        ]
        self.path.write_text("\n".join(map(json.dumps, records)))
        self.event = {"session_id": "test", "transcript_path": str(self.path)}
        for mock in (patch.dict(os.environ, CMUX_WORKSPACE_ID="test-workspace"),
                     patch.object(hook.tempfile, "gettempdir", return_value=self.tmp.name)):
            mock.start()
            self.addCleanup(mock.stop)

    def test_context_filters_instructions(self):
        self.assertEqual(hook.transcript(self.path), ("cli", "cmuxのタブに要約を表示して", "応答本文" * 20))

    @patch.object(hook, "rename")
    @patch.object(hook, "summarize", return_value="タブ要約表示")
    def test_start_cache_and_stale_session(self, summarize, rename):
        hook.main(dict(self.event, hook_event_name="SessionStart"))
        rename.assert_called_with("test-workspace", "Codex 待機")
        hook.main(dict(self.event, hook_event_name="Stop"))
        hook.main(dict(self.event, hook_event_name="Stop"))
        self.assertEqual(summarize.call_count, 1)
        rename.assert_called_with("test-workspace", "Codex タブ要約表示")
        hook.main(dict(self.event, session_id="new", hook_event_name="SessionStart"))
        count = rename.call_count
        hook.main(dict(self.event, hook_event_name="Stop"))
        self.assertEqual(rename.call_count, count)

    @patch.object(hook, "rename")
    def test_noninteractive_ignored(self, rename):
        self.path.write_text(self.path.read_text().replace('"cli"', '"exec"'))
        hook.main(dict(self.event, hook_event_name="SessionStart"))
        rename.assert_not_called()

    @patch.object(hook, "rename")
    def test_switch_during_summary(self, rename):
        hook.main(dict(self.event, hook_event_name="SessionStart"))
        def switch(*_):
            (Path(self.tmp.name) / "cmux_tab_title_test-workspace.session").write_text("new-owner")
            return "古い要約"
        with patch.object(hook, "summarize", side_effect=switch):
            hook.main(dict(self.event, hook_event_name="Stop"))
        self.assertEqual(rename.call_count, 1)

    def test_numbering_keeps_terminal_untouched(self):
        workspaces = {"workspaces": [{"id": "a", "index": 0, "title": "3:Claude 既存"},
                                     {"id": "b", "index": 1, "title": "zsh"},
                                     {"id": "c", "index": 2, "title": "Codex 要約"}]}
        with patch.object(hook, "run_cmux", return_value=json.dumps(workspaces)) as run:
            hook.rename("c", "Codex 要約")
            calls = [call.args for call in run.call_args_list]
        self.assertIn(("rename-workspace", "--workspace", "a", "1:Claude 既存"), calls)
        self.assertIn(("rename-workspace", "--workspace", "c", "3:Codex 要約"), calls)
        self.assertFalse(any("b" in args for args in calls))
