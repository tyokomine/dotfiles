# Claude Code × cmux カスタマイズ

Claude Codeのターミナルカスタマイズ2点セット。

1. **cmuxタブ名の自動要約** — セッショントピックを日本語に要約してcmuxのサイドバータブ名に自動反映するhook
2. **J.A.R.V.I.S.ステータスバー** — アイアンマンHUD配色（ホットロッドレッド×ゴールド）の5行ステータスライン。アークリアクターが12秒周期で呼吸するアニメーション付き

---

# 1. cmuxタブ名の自動要約

## 何をするか

- Claude Codeが自動生成するトピックタイトル（surfaceタイトル）を読み取り、`claude -p --model haiku` で**日本語11文字以内**のタブ名に変換して `rename-workspace` する（例: `2:✳ PP週次レポート改修`）
- 先頭の `2:` は **⌘+数字で飛ぶときの番号**（サイドバーの並び順 = `list-workspaces` の `index`+1）。hookが走るたびに**全タブぶん振り直す**ので、タブを追加・削除・並べ替えしても番号がズレない。番号を付けるのはこのhookが管理するタブ（`✳` / `◌` 始まり）だけで、素のターミナルタブはリネームしない（リネームするとOSCタイトル追従が止まるため）
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

---

# 2. J.A.R.V.I.S.ステータスバー

`statusline-jarvis.sh` がClaude Codeのステータスラインとして5行表示する:

1. セッション情報（cwd・モデル・コンテキスト使用率バー）
2. 5時間ウィンドウ使用率 + 尽きる時刻の予測
3. 7日ウィンドウ使用率 + 尽きる時刻の予測
4. 日次コスト（API換算$、`daily-cost.py` が全セッションのjsonlを集計）
5. バックグラウンドエージェント状況

行頭のアークリアクター（`◌○◎◉`）が12秒周期で「ぼわっ」と呼吸する。`refreshInterval: 1` によりアイドル中もタイマーでアニメーションが動く。

## 前提

- jq / python3 / awk（macOS標準+jqのみ追加）
- `daily-cost.py` は価格表を内蔵しており自己完結（`~/.claude/model-prices.json` があればそちらを優先）

## セットアップ

1. 2ファイルを配置:

   ```sh
   cp statusline-jarvis.sh daily-cost.py ~/.claude/
   chmod +x ~/.claude/statusline-jarvis.sh
   ```

2. `~/.claude/settings.json` に追加:

   ```json
   "statusLine": {
     "type": "command",
     "command": "bash ~/.claude/statusline-jarvis.sh",
     "refreshInterval": 1
   }
   ```

## 実装メモ

- `refreshInterval` の単位は**秒・最小1**。1秒1コマがアニメーション上限速度
- アニメーションフレームはエポック秒から算出（`t % フレーム数`）ステートレス設計
- リアクターは**1グリフ完結**が正解。複数文字構成（コア+外周）はフォント都合で角ばるため不採用
- コストはstandard-tier公開価格による**概算**（1Mコンテキストプレミアム・batch割引は未考慮）。キャッシュは `/tmp/claude-daily-cost-cache.json`（TTL付き）
