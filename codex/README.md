# Codex × cmux

セッション冒頭の依頼と応答から短い日本語要約を作り、`8:Codex タブ要約表示` のようにサイドバーへ表示します。Claude側は `1:Claude …` です。

- SessionStartで `Codex 待機`、入力時・応答完了時に非同期で要約します。再開時はキャッシュを復元します。
- 日本語要約は既存の `~/.local/bin/claude -p --model haiku` を使います。依頼と最初の応答が同じなら再呼び出しません。失敗時は表示を維持し、次回に再試行します。
- cmux外、Codex exec、サブエージェントは対象外です。セッション切替後の遅延更新は破棄します。
- cmuxのワークスペース単位なので、1ワークスペースに1つの対話セッションを想定します。
- ログにはセッションID・要約・ハッシュのみをキャッシュし、会話本文を保存しません。

## 導入

`hooks/cmux_tab_title.py` を `~/.codex/hooks/` へコピーし、`hooks-settings.snippet.json` の `hooks` を `~/.codex/hooks.json` へマージしてください。既存hookは保持します。新しいCodexプロセスから有効です。

Claude側の `../claude-code/hooks/cmux_tab_title.sh` も `~/.claude/hooks/` にコピーします。

[Codex Hooks公式仕様](https://learn.chatgpt.com/docs/hooks)を使用。会話JSONL形式は非安定APIのため、Codex更新で表示されなくなった際は `transcript()` を確認してください。

## 検証

`python3 -m unittest discover -s codex/tests` （dotfiles直下で実行）。
