#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Claude Code StatusLine Script - Design 4: Dashboard Style (Fixed)
"""

import sys
import json
import os
from pathlib import Path
import io
import re

# Set UTF-8 encoding for stdout
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

RESET = "\033[0m"
DIM = "\033[2m"
BOLD = "\033[1m"

# Colors
BLUE = "\033[38;2;100;180;255m"
ORANGE = "\033[38;2;255;160;80m"
GREEN = "\033[38;2;100;220;120m"
CYAN = "\033[38;2;80;200;200m"
RED = "\033[38;2;255;100;100m"
YELLOW = "\033[38;2;255;220;80m"
WHITE = "\033[38;2;240;240;240m"


def format_tokens(num):
    if num >= 1_000_000:
        return f"{round(num / 1_000_000, 1)}m"
    elif num >= 1_000:
        return f"{round(num / 1_000)}k"
    else:
        return str(num)


def get_usage_color(pct):
    """Get color based on usage percentage"""
    if pct >= 90:
        return RED
    elif pct >= 70:
        return YELLOW
    elif pct >= 50:
        return ORANGE
    else:
        return GREEN


def get_remain_color(pct_remain):
    """Get color based on remaining percentage"""
    if pct_remain <= 10:
        return RED
    elif pct_remain <= 30:
        return YELLOW
    elif pct_remain <= 50:
        return ORANGE
    else:
        return CYAN


def build_dashboard_bar(pct, width=15):
    """Build a dashboard-style progress bar"""
    pct = max(0, min(100, pct))
    filled = round(pct * width / 100)
    empty = width - filled

    if pct >= 90:
        bar_color = RED
    elif pct >= 70:
        bar_color = YELLOW
    elif pct >= 50:
        bar_color = ORANGE
    else:
        bar_color = GREEN

    bar = f"{bar_color}{'█' * filled}{DIM}{'░' * empty}{RESET}"
    return bar


def strip_ansi(text):
    """Remove ANSI escape codes to get visible length"""
    ansi_escape = re.compile(r'\033\[[0-9;]*m')
    return ansi_escape.sub('', text)


def pad_line(text, total_width):
    """Pad line to total width based on visible characters"""
    visible_len = len(strip_ansi(text))
    padding_needed = total_width - visible_len - 1  # -1 for the closing │
    if padding_needed > 0:
        return text + (" " * padding_needed)
    return text


def main():
    try:
        input_text = sys.stdin.read()
        
        if not input_text:
            print("Claude", end="")
            return
        
        # Fix invalid JSON escape sequences (e.g. Windows paths like \slidev → \\slidev)
        valid_escapes = {'"', '\\', '/', 'b', 'f', 'n', 'r', 't', 'u'}
        fixed = []
        i = 0
        while i < len(input_text):
            c = input_text[i]
            if c == '\\' and i + 1 < len(input_text):
                next_c = input_text[i + 1]
                if next_c in valid_escapes:
                    fixed.append(c)
                    fixed.append(next_c)
                    i += 2
                else:
                    fixed.append('\\\\')
                    i += 1
            else:
                fixed.append(c)
                i += 1
        input_text = ''.join(fixed)

        data = json.loads(input_text)
        
        model_info = data.get("model") or {}
        model_name = model_info.get("display_name") or "Claude"
        
        context_window = data.get("context_window") or {}
        size = context_window.get("context_window_size") or 200000
        
        usage = context_window.get("current_usage") or {}
        input_tokens = usage.get("input_tokens") or 0
        cache_create = usage.get("cache_creation_input_tokens") or 0
        cache_read = usage.get("cache_read_input_tokens") or 0
        current = input_tokens + cache_create + cache_read
        
        used_tokens = format_tokens(current)
        total_tokens = format_tokens(size)
        pct_used = round((current / size) * 100) if size > 0 else 0
        pct_remain = 100 - pct_used
        
        # Effort Level: 環境変数が最優先
        effort = os.environ.get("CLAUDE_CODE_EFFORT_LEVEL", "").strip().lower()

        # フォールバック: settings.json
        if effort not in ("low", "medium", "high"):
            settings_path = Path.home() / ".claude" / "settings.json"
            if settings_path.exists():
                try:
                    settings = json.loads(settings_path.read_text(encoding="utf-8"))
                    effort = settings.get("effortLevel", "medium").lower()
                    if settings.get("alwaysThinkingEnabled", False):
                        effort = "high"
                except:
                    pass

        if effort not in ("low", "medium", "high"):
            effort = "medium"

        EFFORT_COLORS = {"low": DIM, "medium": CYAN, "high": ORANGE}
        effort_color = EFFORT_COLORS.get(effort, CYAN)

        # キャッシュヒット率
        cache_hit_pct = round((cache_read / current) * 100) if current > 0 else 0
        show_cache = cache_hit_pct >= 5
        
        bar = build_dashboard_bar(pct_used, 15)
        usage_color = get_usage_color(pct_used)
        remain_color = get_remain_color(pct_remain)

        # Box width
        box_width = 65

        # Line 1: Top border with MODEL label
        line1_left = f"┌─ {BOLD}{BLUE}MODEL{RESET} "
        line1_dashes = "─" * (box_width - len(strip_ansi(line1_left)) - 1)
        line1 = line1_left + line1_dashes + "┐"

        # Line 2: Model info
        line2_content = f"│ {CYAN}{model_name}{RESET}  "
        line2_content += f"{DIM}tokens:{RESET} {BOLD}{usage_color}{used_tokens}{RESET}{DIM}/{total_tokens}{RESET}  "
        line2_content += f"{DIM}effort:{RESET} {BOLD}{effort_color}{effort}{RESET} "
        line2 = pad_line(line2_content, box_width) + "│"

        # Line 3: Middle border with USAGE label
        line3_left = f"├─ {BOLD}{usage_color}USAGE{RESET} "
        line3_dashes = "─" * (box_width - len(strip_ansi(line3_left)) - 1)
        line3 = line3_left + line3_dashes + "┤"

        # Line 4: Usage bar
        line4_content = f"│ {bar} {BOLD}{usage_color}{pct_used}%{RESET} used  {DIM}│{RESET}  {BOLD}{remain_color}{pct_remain}%{RESET} remain"
        if show_cache:
            cache_color = GREEN if cache_hit_pct >= 30 else CYAN
            line4_content += f"  {DIM}cache:{RESET} {BOLD}{cache_color}{cache_hit_pct}%{RESET}"
        line4_content += " "
        line4 = pad_line(line4_content, box_width) + "│"
        
        # Line 5: Bottom border
        line5 = "└" + ("─" * (box_width - 2)) + "┘"
        
        print(f"{line1}\n{line2}\n{line3}\n{line4}\n{line5}", end="")
        
    except Exception as e:
        print(f"Claude | Error: {e}", end="")


if __name__ == "__main__":
    main()