# config/claude

Claude Code の設定ファイルを dotfiles として一元管理するディレクトリ。
シンボリックリンクで `~/.claude/` に設置するため、dotfiles を更新すると即時反映される。

## ディレクトリ構造

```
config/claude/
├── .claude/                   # ~/.claude/ へシンボリックリンクで設置
│   ├── agents/
│   │   └── find-skills/
│   │       └── SKILL.md
│   ├── skills/
│   │   └── drawio/
│   │       └── SKILL.md
│   ├── settings.json          # Claude Code グローバル設定（MCP サーバー設定含む）
│   └── statusline.py          # ステータスライン表示用スクリプト
│
├── scripts/
│   └── install.sh             # シンボリックリンクで ~/.claude/ に設置
│
├── skills-lock.json           # スキルバージョン管理
└── README.md
```

## セットアップ

**Windows の場合**: スタートメニューから **「Git Bash」** を起動する（タイトルバーに `MINGW64` と表示される）。
CMD や PowerShell から `bash` を実行すると WSL の bash が起動してしまい、リンクが Windows の `C:\Users\...\` ではなく WSL の `/home/...` に作られるため動作しない。

```sh
bash scripts/install.sh
```

以上で完了。`~/.claude/` 内のファイル・ディレクトリがシンボリックリンクで dotfiles を参照する。

> **Windows でファイルのシンボリックリンクを作成するには権限が必要。** 以下のいずれかを行う:
>
> **推奨: 開発者モードを有効にする**（管理者権限不要）
> 設定 → システム → 開発者向け → 開発者モード → オン
> 有効化後に通常の Git Bash から `bash scripts/install.sh` を再実行する。
>
> **代替: Git Bash を管理者として実行する**
> スタートメニューで「Git Bash」を右クリック → 「管理者として実行」→ `bash scripts/install.sh` を実行する。
> ※ `sudo` は Git Bash（MINGW64）では使用できない。
>
> どちらも行わない場合はハードリンクで代替されるが、`git pull` でソースファイルが置き換わると同期が切れることがある。

### 設置されるリンク

| リンク先（`~/.claude/`）      | dotfiles 内のパス                    |
|-------------------------------|--------------------------------------|
| `settings.json`               | `.claude/settings.json`              |
| `statusline.py`               | `.claude/statusline.py`              |
| `agents/find-skills/`         | `.claude/agents/find-skills/`        |
| `skills/drawio/`              | `.claude/skills/drawio/`             |

### 設置確認

```sh
ls -la ~/.claude/settings.json
ls -la ~/.claude/statusline.py
ls -la ~/.claude/agents/
ls -la ~/.claude/skills/
# Windows での確認
cmd /c "dir /AL %USERPROFILE%\.claude"
```

### 冪等性

`install.sh` は何度実行しても安全。既に正しいリンクが存在する場合は `Already linked, skipping` と表示してスキップする。

## スキル/エージェント管理

| ディレクトリ | 用途 |
|---|---|
| `.claude/agents/` | グローバルエージェント定義（`~/.claude/agents/` へリンク） |
| `.claude/skills/` | グローバルカスタムスキル（`~/.claude/skills/` へリンク） |

`~/.claude/agents/` や `~/.claude/skills/` 内には他ツールのエントリが共存できるよう、
サブディレクトリ単位でリンクを設置する。

`find-skills` 等でスキルをインストールすると `.claude/skills/` に直接追加されるため、
そのまま git 管理対象になる（`git status` で確認可能）。

## MCP サーバー設定

`.claude/settings.json` の `mcpServers` セクションで管理する（全環境共通）。

現在の設定：

| サーバー名 | URL |
|---|---|
| `deepwiki` | `https://mcp.deepwiki.com/mcp` |

認証トークンが必要なサーバー（GitHub MCP など）は `~/.claude/settings.local.json` に記載する（Git 管理外）。

### GitHub MCP の設定例（settings.local.json）

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp",
      "headers": {
        "Authorization": "Bearer <YOUR_GITHUB_PAT>"
      }
    }
  }
}
```

動作確認:

```sh
claude mcp list
```

## rtk (Rust Token Killer) のインストール

```sh
cargo install --git https://github.com/rtk-ai/rtk
rtk gain
```
