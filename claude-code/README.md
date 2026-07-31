# Claude Code × cmux カスタマイズ

Claude Codeのセッショントピックを日本語に要約して、cmuxのサイドバータブ名に自動反映するhook。

## 何をするか

- Claude Codeが自動生成するトピックタイトル（surfaceタイトル）を読み取り、`claude -p --model haiku` で**日本語12文字以内**のタブ名に変換して `rename-workspace` する（例: `✳ PP週次レポート改修`）
- 同一トピックは `$TMPDIR/cmux_tab_title_<WORKSPACE_ID>` にキャッシュし、API再呼び出しなし
- `/clear` や新規起動時は `◌ blank` 表示にリセット（`--blank` モード、SessionStart hook）。resume/compactでは既存タブ名を維持
- cmux外（普通のターミナル）では何もしない安全設計

## 前提

- [cmux](https://cmuxterm.com)（`/Applications/cmux.app`）— `rename-workspace` CLIと `CMUX_WORKSPACE_ID` / `CMUX_SURFACE_ID` 環境変数を利用
- Claude Code CLI（`claude` がPATHにあること。日本語要約にHaikuを1回だけ呼ぶ）
- python3

## セットアップ

1. hookスクリプトを配置:

   ```sh
   mkdir -p ~/.claude/hooks
   cp hooks/cmux_tab_title.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/cmux_tab_title.sh
   ```

2. `hooks-settings.snippet.json` の中身を `~/.claude/settings.json` の `hooks` キーにマージする（UserPromptSubmit / Stop / SessionStart の3イベント。既存のhooksがある場合は配列に追記）。

3. Claude Codeを再起動（新しいセッションからhookが有効になる）。

## 既知の挙動・ハマりどころ

- **cmuxで一度手動リネームしたタブはOSCタイトル追従が止まる**（ピン留め）。このhookは `rename-workspace` を直接叩くので影響しないが、手動リネームと混ぜると混乱しやすい
- トピックタイトルの更新はターン開始から数秒遅れるため、hook内で8秒sleepしてから読み取っている
- サイドバー幅の目安は全角約13文字。12文字で要約させ、13文字でハードトリム
- Haiku呼び出しに失敗した場合は英語トピックを26文字でトリムしてフォールバック
