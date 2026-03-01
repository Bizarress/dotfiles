#!/usr/bin/env bash
# install.sh — dotfiles/config/claude を ~/.claude/ へシンボリックリンクで設置する
#
# 対応OS: Linux, macOS, Windows (MINGW64/Git Bash)
# 冪等性: 既に正しいリンクが存在する場合はスキップ
# バックアップ: 既存の実体ファイル/ディレクトリはタイムスタンプ付きディレクトリに退避

set -euo pipefail

# ---- 定数 ----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$(cd "$SCRIPT_DIR/../.claude" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/dotfiles/$(date +%Y%m%d_%H%M%S)"

# ---- カラー出力 -----------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
skipped() { echo -e "  ${YELLOW}→ Already linked, skipping${NC}"; }

# ---- OS 判定 -------------------------------------------------------------
is_windows() {
  case "$(uname -s)" in
    MINGW*|CYGWIN*|MSYS*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---- Windows cmd コマンド実行（bat 経由でクォーティング問題を回避） ------
# 引数: コマンド文字列（例: "mklink /J \"dst\" \"src\""）
_win_cmd() {
  local tmpbat
  tmpbat=$(mktemp /tmp/wincmd_XXXX.bat)
  printf '@echo off\r\n%s\r\n' "$1" > "$tmpbat"
  local win_bat
  win_bat="$(cygpath -w "$tmpbat")"
  cmd //c "$win_bat" >/dev/null 2>&1
  local ret=$?
  rm -f "$tmpbat"
  return $ret
}

# ---- パス正規化（比較用：Windows 形式に統一） ----------------------------
_win_path() {
  if is_windows; then
    cygpath -w "$1" 2>/dev/null || echo "$1"
  else
    echo "$1"
  fi
}

paths_equal() {
  local a b
  a="$(_win_path "$1")"
  b="$(_win_path "$2")"
  [[ "$a" == "$b" ]]
}

# ---- リンク先取得 --------------------------------------------------------
# JUNCTION も含めて対応（readlink が空を返す場合に fsutil で補完）
_readlink_target() {
  local path="$1"
  local result
  result="$(readlink "$path" 2>/dev/null || true)"
  if [[ -n "$result" ]]; then
    echo "$result"
    return
  fi
  # Windows JUNCTION の場合 readlink が空のことがある → fsutil で取得
  if is_windows; then
    local win_path
    win_path="$(_win_path "$path")"
    result="$(cmd //c "fsutil reparsepoint query \"$win_path\"" 2>/dev/null \
      | grep -i "Print Name" | sed 's/.*: //' | tr -d '\r' \
      | sed 's|^\\\\?\\||g' | sed 's|^\\??\\||g' || true)"
    if [[ -n "$result" ]]; then
      echo "$result"
      return
    fi
  fi
  echo ""
}

# ---- リンク/ジャンクション判定 ------------------------------------------
_is_link() {
  local path="$1"
  [[ -L "$path" ]] && return 0
  # MINGW64 では Junction が -L で検出されることがある（上記で十分なことが多い）
  # 念のため Windows の reparse point チェックも行う
  if is_windows && [[ -d "$path" ]]; then
    local win_path
    win_path="$(_win_path "$path")"
    cmd //c "fsutil reparsepoint query \"$win_path\"" >/dev/null 2>&1 && return 0
  fi
  return 1
}

# ---- ハードリンク判定（同一 inode チェック） ----------------------------
_is_hardlink() {
  local path1="$1" path2="$2"
  local i1 i2
  i1="$(stat -c '%i' "$path1" 2>/dev/null || true)"
  i2="$(stat -c '%i' "$path2" 2>/dev/null || true)"
  [[ -n "$i1" && -n "$i2" && "$i1" == "$i2" ]]
}

# ---- バックアップ ---------------------------------------------------------
backup_if_exists() {
  local target="$1"
  if [[ -e "$target" ]] && ! _is_link "$target"; then
    mkdir -p "$BACKUP_DIR"
    local name
    name="$(basename "$target")"
    warn "既存の実体ファイル/ディレクトリを退避: $target → $BACKUP_DIR/$name"
    mv "$target" "$BACKUP_DIR/$name"
  fi
}

# ---- ファイルリンク設置 ---------------------------------------------------
link_file() {
  local src="$1"   # 絶対パス（dotfiles 側、MSYS形式）
  local dst="$2"   # 絶対パス（~/.claude/ 側、MSYS形式）
  local name
  name="$(basename "$dst")"

  # 1) 既にシンボリックリンクが正しい場所を指している？
  if [[ -L "$dst" ]]; then
    local current_target
    current_target="$(_readlink_target "$dst")"
    if paths_equal "$current_target" "$src"; then
      info "FILE: $name"
      skipped
      return
    fi
    # 不正なリンク先 → 削除して再作成
    rm "$dst"
  fi

  # 2) ハードリンクとして同一 inode？
  if [[ -f "$dst" ]] && _is_hardlink "$dst" "$src"; then
    info "FILE: $name"
    skipped
    return
  fi

  backup_if_exists "$dst"
  mkdir -p "$(dirname "$dst")"

  if is_windows; then
    local win_src win_dst
    win_src="$(_win_path "$src")"
    win_dst="$(_win_path "$dst")"

    # 試行 1: mklink（Windows シンボリックリンク、開発者モードが必要）
    if _win_cmd "mklink \"$win_dst\" \"$win_src\""; then
      info "FILE (symlink): $name → $src"
      return
    fi

    # 試行 2: mklink /H（ハードリンク、管理者権限・開発者モード不要）
    if _win_cmd "mklink /H \"$win_dst\" \"$win_src\""; then
      warn "開発者モードが無効のためハードリンクを使用（有効化するとシンボリックリンクに変更可能）"
      info "FILE (hardlink): $name"
      return
    fi

    # 試行 3: コピーにフォールバック（dotfiles 変更時は再実行が必要）
    warn "リンク作成失敗。コピーで代替します（dotfiles 変更時は再実行が必要）: $name"
    cp "$src" "$dst"
    info "FILE (copy): $name"
  else
    if ln -sf "$src" "$dst"; then
      info "FILE (symlink): $name → $src"
    else
      error "シンボリックリンク作成失敗: $dst"
      return 1
    fi
  fi
}

# ---- ディレクトリジャンクション/リンク設置 --------------------------------
link_dir() {
  local src="$1"   # 絶対パス（dotfiles 側、MSYS形式）
  local dst="$2"   # 絶対パス（~/.claude/ 側、MSYS形式）
  local name
  name="$(basename "$dst")"

  # 既にリンク/ジャンクションが正しい場所を指している？
  if _is_link "$dst"; then
    local current_target
    current_target="$(_readlink_target "$dst")"
    if paths_equal "$current_target" "$src"; then
      info "DIR:  $name/"
      skipped
      return
    fi
    # 不正なリンク先 → 削除して再作成
    if is_windows; then
      local win_dst
      win_dst="$(_win_path "$dst")"
      _win_cmd "rmdir \"$win_dst\"" || rm -rf "$dst"
    else
      rm -rf "$dst"
    fi
  fi

  backup_if_exists "$dst"
  mkdir -p "$(dirname "$dst")"

  if is_windows; then
    local win_src win_dst
    win_src="$(_win_path "$src")"
    win_dst="$(_win_path "$dst")"

    # mklink /J（JUNCTION）— 管理者権限・開発者モード不要
    if _win_cmd "mklink /J \"$win_dst\" \"$win_src\""; then
      info "DIR (junction): $name/ → $src"
      return
    fi
    error "JUNCTION 作成失敗: $dst"
    return 1
  else
    if ln -sfn "$src" "$dst"; then
      info "DIR (symlink): $name/ → $src"
    else
      error "シンボリックリンク作成失敗: $dst"
      return 1
    fi
  fi
}

# ---- メイン処理 ----------------------------------------------------------
main() {
  echo ""
  echo "Claude Code dotfiles インストール"
  echo "  dotfiles: $GLOBAL_DIR"
  echo "  target:   $CLAUDE_DIR"
  echo ""

  mkdir -p "$CLAUDE_DIR"

  # ファイルリンク
  link_file "$GLOBAL_DIR/settings.json" "$CLAUDE_DIR/settings.json"
  link_file "$GLOBAL_DIR/statusline.py" "$CLAUDE_DIR/statusline.py"

  # agents/ 配下の各エントリをサブディレクトリ単位でリンク
  local agents_src="$GLOBAL_DIR/agents"
  local agents_dst="$CLAUDE_DIR/agents"
  mkdir -p "$agents_dst"
  for entry in "$agents_src"/*/; do
    [[ -d "$entry" ]] || continue
    local name
    name="$(basename "$entry")"
    link_dir "$agents_src/$name" "$agents_dst/$name"
  done

  # skills/ 配下の各エントリをサブディレクトリ単位でリンク
  local skills_src="$GLOBAL_DIR/skills"
  local skills_dst="$CLAUDE_DIR/skills"
  mkdir -p "$skills_dst"
  for entry in "$skills_src"/*/; do
    [[ -d "$entry" ]] || continue
    local name
    name="$(basename "$entry")"
    link_dir "$skills_src/$name" "$skills_dst/$name"
  done

  echo ""
  info "完了。"
  echo ""
  echo "確認コマンド:"
  echo "  ls -la ~/.claude/settings.json"
  echo "  ls -la ~/.claude/statusline.py"
  echo "  ls -la ~/.claude/agents/"
  echo "  ls -la ~/.claude/skills/"
  if is_windows; then
    echo "  cmd /c \"dir /AL %USERPROFILE%\\.claude\""
  fi
}

main "$@"
