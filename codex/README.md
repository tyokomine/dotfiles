# Codex × cmux

セッション冒頭の依頼と応答から短い日本語要約を作り、`8:Codex タブ要約表示` のようにサイドバーへ表示します。Claude側は `1:Claude …` です。

- SessionStartで `Codex 待機`、入力時・応答完了時に非同期で要約します。再開時はキャッシュを復元します。
- Codex 0.154.0では `/clear` 直後にSessionStartが発火しないため、`cmux_title_watch.py` がターミナルタイトルのリセットと初期画面を検知し、約1秒で `Codex 待機` に戻します。旧セッションの遅延更新も無効化します。
- 監視は全Codexタブで1プロセスを共有し、保持したcmuxソケットを使います。監視周期ごとのCLI起動・AI呼び出しはありません。対象がなくなるか接続が失われると終了し、次のhookで自動起動します。cmuxのアクセス制限は変更しません。
- 日本語要約は既存の `~/.local/bin/claude -p --model haiku` を使います。依頼と最初の応答が同じなら再呼び出しません。失敗時は表示を維持し、次回に再試行します。
- cmux外、Codex exec、サブエージェントは対象外です。セッション切替後の遅延更新は破棄します。
- cmuxのワークスペース単位なので、1ワークスペースに1つの対話セッションを想定します。
- ログにはセッションID・要約・ハッシュのみをキャッシュし、会話本文を保存しません。

## 導入

`hooks/cmux_tab_title.py` と `hooks/cmux_title_watch.py` を `~/.codex/hooks/` へコピーし、`hooks-settings.snippet.json` の `hooks` を `~/.codex/hooks.json` へマージしてください。既存hookは保持します。既存の導入環境では次のhookから反映され、新規導入では新しいCodexプロセスから有効です。

Claude側の `../claude-code/hooks/cmux_tab_title.sh` も `~/.claude/hooks/` にコピーします。

[Codex Hooks公式仕様](https://learn.chatgpt.com/docs/hooks)を使用。会話JSONL形式は非安定APIのため、Codex更新で表示されなくなった際は `transcript()` を確認してください。

## 検証

`python3 -m unittest discover -s codex/tests` （dotfiles直下で実行）。
