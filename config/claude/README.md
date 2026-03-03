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

| リンク先（`~/.claude/`） | dotfiles 内のパス             |
| ------------------------ | ----------------------------- |
| `settings.json`          | `.claude/settings.json`       |
| `statusline.py`          | `.claude/statusline.py`       |
| `agents/find-skills/`    | `.claude/agents/find-skills/` |
| `skills/drawio/`         | `.claude/skills/drawio/`      |

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

| ディレクトリ      | 用途                                                       |
| ----------------- | ---------------------------------------------------------- |
| `.claude/agents/` | グローバルエージェント定義（`~/.claude/agents/` へリンク） |
| `.claude/skills/` | グローバルカスタムスキル（`~/.claude/skills/` へリンク）   |

`~/.claude/agents/` や `~/.claude/skills/` 内には他ツールのエントリが共存できるよう、
サブディレクトリ単位でリンクを設置する。

`find-skills` 等でスキルをインストールすると `.claude/skills/` に直接追加されるため、
そのまま git 管理対象になる（`git status` で確認可能）。

## MCP サーバー設定

### 重要: 設定ファイルについて

MCP サーバーの追加には `claude mcp add` コマンドを使う：

```sh
# HTTP サーバー（認証なし）
claude mcp add --transport http --scope user <name> <url>

# HTTP サーバー（認証あり）
claude mcp add --transport http --scope user <name> <url> --header "Authorization: Bearer <TOKEN>"

# stdio サーバー
claude mcp add --scope user <name> -- <command> [args...]
```

**スコープと保存先：**

| スコープ  | 保存先                             | Git 管理 | 用途                                   |
| --------- | ---------------------------------- | -------- | -------------------------------------- |
| `user`    | `~/.claude.json`（グローバル）     | 対象外   | 全プロジェクトで使うサーバー           |
| `local`   | `~/.claude.json`（プロジェクト別） | 対象外   | 特定プロジェクトのみ（デフォルト）     |
| `project` | `.claude/settings.json`            | **対象** | チーム共有（機密情報は絶対に入れない） |

> **注意: `user` / `local` スコープは dotfiles の管理対象外**
>
> `user` および `local` スコープの設定は `~/.claude.json` に保存される。
> このファイルは PAT 等のシークレットを含む可能性があるため **dotfiles リポジトリには含めていない**。
> そのため、新しい環境をセットアップした際は [おすすめ MCP サーバー](#おすすめ-mcp-サーバー) を参考に
> 手動で `claude mcp add` を実行してインストールすること。

> **注意: MCP サーバーの無効化はプロジェクト単位のみ**
>
> `/mcp` コマンド（Claude Code 内）から MCP サーバーを disable にした場合、
> その設定は現在のプロジェクトの `.claude/settings.local.json` にのみ保存される。
> グローバルに無効化する手段はなく、不要なサーバーはアンインストールするか
> `~/.claude.json` を直接編集して削除する必要がある。

動作確認:

```sh
claude mcp list
```

---

### おすすめ MCP サーバー

#### deepwiki

GitHub リポジトリのドキュメントを AI で検索・参照できるサーバー。ライブラリの仕様確認などに便利。

```sh
claude mcp add --transport http --scope user deepwiki https://mcp.deepwiki.com/mcp
```

#### pencil

[Pencil](https://pencil.tinyfish.io/) デスクトップアプリの MCP サーバー。Claude から UI デザインを直接操作できる。

**前提**: Pencil デスクトップアプリがインストール済みであること。

```sh
claude mcp add --scope user pencil -- \
  "$LOCALAPPDATA/Programs/Pencil/resources/app.asar.unpacked/out/mcp-server-windows-x64.exe" \
  --app desktop
```

> Pencil のインストールパスは環境によって異なる場合がある。
> `$LOCALAPPDATA/Programs/Pencil/` 以下を確認すること。

#### github

GitHub の Issue・PR・コードを Claude から操作できるサーバー。

```sh
claude mcp add-json github '{"type":"http","url":"https://api.githubcopilot.com/mcp","headers":{"Authorization":"Bearer YOUR_GITHUB_PAT"}}'
```

> PAT は [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens) で発行する。

## rtk (Rust Token Killer) のインストール

### 1. Rust のインストール

rtk は Rust 製ツールのため、先に Rust ツールチェーンをインストールする。

```sh
# rustup インストーラーを実行（Git Bash / macOS / Linux）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

> **Windows の場合**: ブラウザで https://rustup.rs を開いて `rustup-init.exe` をダウンロード・実行する方法も使える。
> インストール後、**新しい Git Bash を開き直して** `PATH` を反映させること。

インストール確認:

```sh
rustc --version   # 例: rustc 1.78.0 (...)
cargo --version   # 例: cargo 1.78.0 (...)
```

### 2. rtk のインストール

```sh
cargo install --git https://github.com/rtk-ai/rtk
```

> `~/.cargo/bin` が `PATH` に含まれていない場合は `source ~/.cargo/env` を実行するか、
> `~/.bashrc` / `~/.bash_profile` に `source ~/.cargo/env` を追記する。

### 3. rtk を Claude Code に登録する

```sh
rtk init -g
```

`-g` / `--global` オプションを付けることで、全プロジェクト共通の `~/.claude/CLAUDE.md` に RTK の使用指示が書き込まれる。
省略すると現在のプロジェクトの `CLAUDE.md` にのみ適用される。

> オプション一覧:
>
> | フラグ | 説明 |
> | --- | --- |
> | `-g`, `--global` | グローバル設定（`~/.claude/CLAUDE.md`）に追加 |
> | `--auto-patch` | `settings.json` を自動パッチ（確認なし） |
> | `--no-patch` | `settings.json` の変更をスキップ（手動手順を出力） |
> | `--uninstall` | RTK のすべての設定を削除 |

### 4. 動作確認・トークン節約統計

```sh
rtk gain           # トークン節約の統計を表示
rtk gain --history # コマンド履歴と節約量を表示
rtk discover       # Claude Code セッションから RTK 未使用箇所を分析
```
