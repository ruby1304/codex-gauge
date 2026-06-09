# codex-gauge

A **zero-cost** macOS menu-bar gauge for your **Codex (ChatGPT) usage limits** — 5-hour window + weekly window, remaining % and reset times, right in your menu bar.

The trick: it reads the rate-limit snapshot that the Codex CLI **already writes to your local session logs**. It never calls any API, never touches your token, never spends a single unit of quota.

> **Checking the fuel gauge should never burn fuel.** Other usage widgets poll an endpoint on a timer; codex-gauge just reads a file Codex already wrote. The numbers refresh for free whenever Codex actually runs.

## Look

```
 menu bar:   ◕ 71%

 ┌────────────────────────────────────────────┐
 │  Codex 用量 · prolite                        │
 │  快照 4 分钟前                                │
 │  ────────────────────────────────────────   │
 │  ●  5 小时窗   剩 98%   ·   6/9 16:16 重置    │  (green)
 │        ▰▰▰▰▰▰▰▰▰▰                            │
 │  ◕  本周窗     剩 71%   ·   6/11 09:43 重置   │  (green)
 │        ▰▰▰▰▰▰▰░░░                            │
 │  ────────────────────────────────────────   │
 │  ↻ 刷新（重读本地 · 免费）                    │
 │  codex-gauge · GitHub                        │
 └────────────────────────────────────────────┘
```

Color encodes status only: **green** ≥30% left · **amber** 10–30% · **red** <10%. The menu-bar title stays calm (neutral) until a window drops low, then it turns amber/red so you notice without staring.

## Install

1. Install [SwiftBar](https://github.com/swiftbar/SwiftBar) (free, open-source menu-bar host). Also works with [xbar](https://github.com/matryer/xbar).
   ```sh
   brew install --cask swiftbar
   ```
2. Clone this repo and run the installer (symlinks the plugin into your SwiftBar plugin folder):
   ```sh
   git clone https://github.com/ruby1304/codex-gauge.git
   cd codex-gauge && ./install.sh
   ```
   Or just drop `codex-gauge.1m.py` into your SwiftBar plugin folder yourself and `chmod +x` it.
3. Launch SwiftBar. You'll see `◕ 71%` in the menu bar. Click it for the breakdown.

**Requirements:** macOS, Python 3 (system one is fine), the Codex CLI, and at least one Codex session having run (so a session log with rate-limit data exists).

## How it works

Every Codex API response carries your current rate-limit state, and the Codex CLI persists it into each session log at `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` as a `rate_limits` object:

```json
{ "rate_limits": {
    "primary":   { "used_percent": 2.0,  "window_minutes": 300,   "resets_at": 1780992992 },
    "secondary": { "used_percent": 29.0, "window_minutes": 10080,  "resets_at": 1781142220 },
    "plan_type": "prolite" } }
```

`primary` is the 5-hour rolling window, `secondary` is the weekly window. codex-gauge finds the newest session log, reads the last `rate_limits` block, and shows `100 − used_percent` as "remaining". That's the whole thing — a local file read.

**Freshness caveat:** the snapshot is from the last time Codex actually ran. If you haven't used Codex in a while it'll read older — but that's fine, because if Codex isn't running, your quota isn't moving either. The numbers update for free the next time Codex does real work. There is deliberately **no** "force refresh" in this menu, because forcing a refresh would mean sending a real Codex request and spending quota — exactly what this tool refuses to do. (If you ever truly need an up-to-the-second value, run a Codex command yourself.)

## FAQ

**Does it cost any quota / tokens?** No. It only reads local files. It makes zero network requests.

**Does it need my OpenAI/ChatGPT token?** No. It never reads or touches `~/.codex/auth.json` or any credential.

**Why not poll the usage endpoint for live numbers?** Because that spends a request every tick and, for some providers, risks getting flagged. Passive file reading is free and safe.

## Prior art / thanks

- The same local `rate_limits` data source is also used by [`xiangz19/codex-ratelimit`](https://github.com/xiangz19/codex-ratelimit) (CLI / JSON / TUI). codex-gauge is the always-visible menu-bar take.
- [SwiftBar](https://github.com/swiftbar/SwiftBar) does the menu-bar hosting.

## License

MIT © 2026 ruby1304
