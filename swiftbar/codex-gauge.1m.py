#!/usr/bin/env python3
# codex-gauge — a zero-cost macOS menu-bar gauge for your Codex (ChatGPT) usage limits.
#
# It reads the rate-limit snapshot that the Codex CLI already writes to your local
# session logs (~/.codex/sessions/**/rollout-*.jsonl). It NEVER calls any API, never
# touches your token, never spends a single unit of quota. The numbers refresh for
# free whenever Codex actually runs — checking the fuel gauge never burns fuel.
#
# SwiftBar plugin (also works in xbar). Filename "*.1m.py" => refresh every 60s,
# which is just a cheap local file read. Manual "refresh" in the menu re-reads too.
#
# https://github.com/ruby1304/codex-gauge   ·   MIT
import json, glob, os, time

# Status palette only (Smartisan OS: color encodes status, never decoration).
GOOD, WARN, BAD = "#0e8a4f", "#c98a14", "#e0411b"   # green / amber / accent-red

def status_color(rem):
    if rem is None:
        return None
    if rem < 10:
        return BAD
    if rem < 30:
        return WARN
    return GOOD

_FILL = "●◕◑◔○"  # full -> empty quarter-circles
def glyph(rem):
    if rem is None:
        return "○"
    return (_FILL[0] if rem >= 87 else _FILL[1] if rem >= 62 else
            _FILL[2] if rem >= 37 else _FILL[3] if rem >= 12 else _FILL[4])

def bar(rem, n=10):
    if rem is None:
        return "▱" * n
    f = max(0, min(n, int(round(rem / 100 * n))))
    return "▰" * f + "▱" * (n - f)

def _find_rl(o):
    if isinstance(o, dict):
        rl = o.get("rate_limits")
        if isinstance(rl, dict) and ("primary" in rl or "secondary" in rl):
            return rl
        for v in o.values():
            r = _find_rl(v)
            if r:
                return r
    elif isinstance(o, list):
        for v in o:
            r = _find_rl(v)
            if r:
                return r
    return None

def latest_rate_limits():
    base = os.path.expanduser("~/.codex/sessions")
    files = sorted(glob.glob(os.path.join(base, "**", "rollout-*.jsonl"), recursive=True),
                   key=os.path.getmtime, reverse=True)
    for f in files[:8]:
        found = None
        try:
            with open(f) as fh:
                for line in fh:
                    if '"rate_limits"' in line:
                        try:
                            r = _find_rl(json.loads(line))
                            if r:
                                found = r
                        except Exception:
                            pass
        except Exception:
            continue
        if found:
            return found, (time.time() - os.path.getmtime(f)) / 60
    return None, None

def remaining(w):
    if not isinstance(w, dict):
        return None
    for k in ("used_percent", "used_percentage", "utilization"):
        v = w.get(k)
        if isinstance(v, (int, float)):
            return 100 - v
    return None

def reset_str(w):
    if not isinstance(w, dict):
        return ""
    ra = w.get("resets_at")
    if not ra:
        return ""
    t = time.localtime(ra)
    return f"{t.tm_mon}/{t.tm_mday} {t.tm_hour:02d}:{t.tm_min:02d}"

def ago(mins):
    if mins is None:
        return "—"
    if mins < 60:
        return f"{mins:.0f} 分钟前"
    if mins < 1440:
        return f"{mins / 60:.0f} 小时前"
    return f"{mins / 1440:.0f} 天前"

rl, age = latest_rate_limits()
p5 = remaining(rl.get("primary")) if rl else None
pw = remaining(rl.get("secondary")) if rl else None
plan = (rl or {}).get("plan_type", "")

# ---- menu-bar title: weekly fill-glyph + %, calm by default, colored only when low ----
title_rem = pw if pw is not None else p5
mins = [x for x in (p5, pw) if x is not None]
tcolor = status_color(min(mins)) if mins else None
if title_rem is None:
    print("◌ codex")
else:
    seg = f"{glyph(title_rem)} {title_rem:.0f}%"
    print(seg + (f" | color={tcolor}" if tcolor in (WARN, BAD) else ""))
print("---")

if rl is None:
    print("还没读到额度 | size=12")
    print("跑过一次 codex 之后就有了 | size=11")
else:
    print(f"Codex 用量{(' · ' + plan) if plan else ''} | size=12")
    print(f"快照 {ago(age)} | size=11")
    print("---")
    for label, p, w in (("5 小时窗", p5, rl.get("primary")),
                        ("本周窗", pw, rl.get("secondary"))):
        c = status_color(p)
        col = f" color={c}" if c else ""
        ps = f"{p:.0f}%" if p is not None else "—"
        rs = reset_str(w)
        print(f"{glyph(p)}  {label}   剩 {ps}   ·   {rs} 重置 | size=13{col}")
        print(f"      {bar(p)} | font=Menlo size=12{col}")
print("---")
print("↻ 刷新（重读本地 · 免费） | refresh=true size=12")
print("codex-gauge · GitHub | href=https://github.com/ruby1304/codex-gauge size=11")
print("零消耗:只读本地 session 文件,不碰任何 API / token | size=10")
