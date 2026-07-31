#!/usr/bin/env python3
"""Aggregate Claude Code token usage across ALL sessions/windows and estimate
the equivalent pay-as-you-go API cost (USD) for today and yesterday.

Reads ~/.claude/projects/**/*.jsonl transcripts, dedupes by message id +
request id, groups by local calendar day, and applies standard-tier list
prices. Output is a single JSON object on stdout.

Cost is an ESTIMATE: it uses public standard-tier list prices and does not
account for the 1M-context (>200K) premium tier, batch discounts, or
server-tool (web search/fetch) surcharges.
"""
import json
import os
import subprocess
import sys
import glob
import time
from datetime import datetime, timedelta

PROJECTS_DIR = os.path.expanduser("~/.claude/projects")

# Embedded fallback prices, USD per 1M tokens (as of 2026-06).
# Used only when model-prices.json is missing or has no matching entry.
# (input, output, cache_write_5m, cache_write_1h, cache_read)
#
# NOTE: sonnet-5 (claude-sonnet-5) intentionally relies on this fallback.
# The official pricing page splits it into two date-qualified rows
# ("...through August 31, 2026" / "...starting September 1, 2026"), so the
# fetched-table slugs are longer than the model id and never substring-match.
# Sonnet's fallback below is set to the current promo rate ($2/$10 in effect
# through 2026-08-31). Bump it to the post-promo rate ($3/$15, 3.75/6.0/0.30)
# when refreshing the price table on 2026-09-01.
PRICES = {
    "fable":  (10.0, 50.0, 12.5,  20.0, 1.00),
    "opus":   (5.0,  25.0, 6.25,  10.0, 0.50),
    "sonnet": (2.0,  10.0, 2.5,   4.0,  0.20),
    "haiku":  (1.0,  5.0,  1.25,  2.0,  0.10),
}
DEFAULT = PRICES["sonnet"]

# Live price table fetched daily from the official pricing page by
# update-model-prices.py. Keys are name slugs ("fable-5", "opus-4-8", ...)
# matched against transcript model IDs by longest-substring match.
PRICE_FILE = os.path.expanduser("~/.claude/model-prices.json")
PRICE_UPDATER = os.path.expanduser("~/.claude/update-model-prices.py")
PRICE_MAX_AGE = 24 * 3600
UPDATE_MARKER = "/tmp/claude-price-update-attempt"
UPDATE_RETRY = 3600

UNKNOWN_MODELS = set()


def load_fetched_prices():
    """Returns [(slug, rates_tuple)] sorted longest-slug-first, or []."""
    try:
        with open(PRICE_FILE, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        entries = []
        for slug, p in data["prices"].items():
            entries.append((slug, (
                p["input"], p["output"],
                p["cache_write_5m"], p["cache_write_1h"], p["cache_read"],
            )))
        entries.sort(key=lambda e: len(e[0]), reverse=True)
        return entries
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        return []


def maybe_refresh_prices():
    """Kick the price updater in the background if the table is stale.

    Never blocks: the current run keeps using whatever data is on disk.
    Attempts are throttled to once per UPDATE_RETRY seconds.
    """
    now = time.time()
    try:
        if now - os.path.getmtime(PRICE_FILE) < PRICE_MAX_AGE:
            return
    except OSError:
        pass  # file missing -> refresh
    try:
        if now - os.path.getmtime(UPDATE_MARKER) < UPDATE_RETRY:
            return
    except OSError:
        pass
    try:
        with open(UPDATE_MARKER, "w") as fh:
            fh.write(str(int(now)))
        if os.path.isfile(PRICE_UPDATER):
            subprocess.Popen(
                [sys.executable, PRICE_UPDATER],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
    except OSError:
        pass


FETCHED_PRICES = load_fetched_prices()


def rates_for(model: str):
    m = (model or "").lower()
    for slug, rates in FETCHED_PRICES:
        if slug in m:
            return rates
    for family in ("fable", "opus", "sonnet", "haiku"):
        if family in m:
            return PRICES[family]
    if m and m != "<synthetic>":
        UNKNOWN_MODELS.add(model)
    return DEFAULT


def cost_of(usage: dict, model: str) -> float:
    p_in, p_out, p_cw5, p_cw1, p_cr = rates_for(model)
    inp = usage.get("input_tokens", 0) or 0
    out = usage.get("output_tokens", 0) or 0
    cr = usage.get("cache_read_input_tokens", 0) or 0
    cc = usage.get("cache_creation_input_tokens", 0) or 0
    breakdown = usage.get("cache_creation") or {}
    cw1 = breakdown.get("ephemeral_1h_input_tokens", 0) or 0
    cw5 = breakdown.get("ephemeral_5m_input_tokens", 0) or 0
    if cw1 == 0 and cw5 == 0:
        cw5 = cc  # no breakdown -> assume 5m
    return (
        inp * p_in
        + out * p_out
        + cr * p_cr
        + cw5 * p_cw5
        + cw1 * p_cw1
    ) / 1_000_000.0


HISTORY_FILE = os.path.expanduser("~/.claude/daily-cost-history.json")
WEEK_DAYS = 7


def main():
    maybe_refresh_prices()
    now = datetime.now().astimezone()
    today = now.date()
    yesterday = today - timedelta(days=1)
    week = [today - timedelta(days=i) for i in range(WEEK_DAYS - 1, -1, -1)]

    # --today-only: scan just today and emit a minimal payload. Lets the
    # statusline refresh today's figure on a short TTL without paying for the
    # full yesterday+week aggregation on every tick.
    today_only = "--today-only" in sys.argv

    # Completed days (before yesterday) are frozen in a history file so the
    # steady-state scan only needs to cover today + yesterday.
    history = {}
    if not today_only:
        try:
            with open(HISTORY_FILE, "r", encoding="utf-8") as fh:
                history = json.load(fh)
        except (OSError, json.JSONDecodeError):
            history = {}

    # Days we must (re)scan: today, yesterday, and any week day missing from history.
    if today_only:
        scan_days = {str(today)}
    else:
        scan_days = {str(today), str(yesterday)}
        for d in week[:-2]:
            if str(d) not in history:
                scan_days.add(str(d))
    oldest_scan = min(datetime.fromisoformat(d).date() for d in scan_days)
    cutoff = (
        datetime.combine(oldest_scan, datetime.min.time()).astimezone()
        - timedelta(days=1)
    ).timestamp()

    seen = set()
    agg = {d: {"cost": 0.0, "tokens": 0} for d in scan_days}
    # 直近5時間のローリング集計（今日/昨日は full モードで必ずスキャンされるため網羅できる）
    five_cutoff = now - timedelta(hours=5)
    five = {"cost": 0.0, "tokens": 0}

    for path in glob.iglob(os.path.join(PROJECTS_DIR, "**", "*.jsonl"), recursive=True):
        try:
            if os.path.getmtime(path) < cutoff:
                continue
        except OSError:
            continue
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    line = line.strip()
                    if not line or '"usage"' not in line:
                        continue
                    try:
                        rec = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    msg = rec.get("message") or {}
                    usage = msg.get("usage")
                    if not usage:
                        continue
                    ts = rec.get("timestamp")
                    if not ts:
                        continue
                    try:
                        dt = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()
                    except ValueError:
                        continue
                    day = str(dt.date())
                    if day not in agg:
                        continue
                    key = (msg.get("id"), rec.get("requestId"))
                    if key != (None, None) and key in seen:
                        continue
                    seen.add(key)
                    model = msg.get("model", "")
                    c = cost_of(usage, model)
                    tk = (
                        (usage.get("input_tokens", 0) or 0)
                        + (usage.get("output_tokens", 0) or 0)
                        + (usage.get("cache_read_input_tokens", 0) or 0)
                        + (usage.get("cache_creation_input_tokens", 0) or 0)
                    )
                    agg[day]["cost"] += c
                    agg[day]["tokens"] += tk
                    if dt >= five_cutoff:
                        five["cost"] += c
                        five["tokens"] += tk
        except OSError:
            continue

    if today_only:
        print(json.dumps({
            "today": round(agg[str(today)]["cost"], 2),
            "today_tokens": agg[str(today)]["tokens"],
            "date": str(today),
            "unknown_models": sorted(UNKNOWN_MODELS),
        }))
        return

    # Freeze completed days (anything before today) into history.
    changed = False
    for d, v in agg.items():
        if d != str(today):
            entry = {"cost": round(v["cost"], 2), "tokens": v["tokens"]}
            if history.get(d) != entry:
                history[d] = entry
                changed = True
    if changed:
        try:
            with open(HISTORY_FILE, "w", encoding="utf-8") as fh:
                json.dump(history, fh)
        except OSError:
            pass

    def day_entry(d):
        ds = str(d)
        if ds in agg:
            return {"cost": round(agg[ds]["cost"], 2), "tokens": agg[ds]["tokens"]}
        return history.get(ds, {"cost": 0.0, "tokens": 0})

    week_entries = [dict(date=str(d), **day_entry(d)) for d in week]
    seven_cost = round(sum(e["cost"] for e in week_entries), 2)
    seven_tokens = sum(e["tokens"] for e in week_entries)

    out = {
        "today": round(agg[str(today)]["cost"], 2),
        "yesterday": round(agg[str(yesterday)]["cost"], 2),
        "today_tokens": agg[str(today)]["tokens"],
        "yesterday_tokens": agg[str(yesterday)]["tokens"],
        "week": week_entries,
        "five_hour": {"cost": round(five["cost"], 2), "tokens": five["tokens"]},
        "seven_day": {"cost": seven_cost, "tokens": seven_tokens},
        "unknown_models": sorted(UNKNOWN_MODELS),
        "prices_fetched_at": (
            datetime.fromtimestamp(os.path.getmtime(PRICE_FILE)).astimezone().isoformat()
            if os.path.isfile(PRICE_FILE) else None
        ),
    }
    print(json.dumps(out))


if __name__ == "__main__":
    main()
