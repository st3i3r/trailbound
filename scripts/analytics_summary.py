#!/usr/bin/env python3
"""Café builder analytics summary (stdlib only).

Reads CAFE_DB env var (default ~/workspace/cafe-builder-3d/cafe.db) and prints:
  - total users
  - total analytics events
  - funnel: session_start -> ftue_done -> returning users
      (2+ distinct UTC dates with any event)
  - avg serves per user, avg tip (from serve props)

Handles a missing or empty DB gracefully.
"""
import json
import os
import sqlite3
import sys

DB_PATH = os.path.expanduser(
    os.environ.get("CAFE_DB", "~/workspace/cafe-builder-3d/cafe.db"))


def main():
    if not os.path.exists(DB_PATH):
        print(f"DB not found: {DB_PATH}")
        return 0
    try:
        con = sqlite3.connect(DB_PATH)
        con.row_factory = sqlite3.Row
    except sqlite3.Error as e:
        print(f"cannot open DB {DB_PATH}: {e}")
        return 1

    try:
        tables = {r[0] for r in con.execute(
            "SELECT name FROM sqlite_master WHERE type='table'")}
        if "users" not in tables:
            print(f"{DB_PATH}: no users table (fresh/empty DB)")
            return 0
        total_users = con.execute("SELECT COUNT(*) FROM users").fetchone()[0]

        if "analytics_events" not in tables:
            print(f"total users: {total_users}")
            print("total analytics events: 0 (analytics_events table missing)")
            return 0
        total_events = con.execute(
            "SELECT COUNT(*) FROM analytics_events").fetchone()[0]

        def distinct_users(event=None):
            if event is None:
                return con.execute(
                    "SELECT COUNT(DISTINCT user_id) FROM analytics_events"
                ).fetchone()[0]
            return con.execute(
                "SELECT COUNT(DISTINCT user_id) FROM analytics_events WHERE event=?",
                (event,)).fetchone()[0]

        n_session = distinct_users("session_start")
        n_ftue = distinct_users("ftue_done")
        # returning = 2+ distinct UTC dates with any event
        n_returning = con.execute(
            """SELECT COUNT(*) FROM (
                   SELECT user_id FROM analytics_events
                   GROUP BY user_id
                   HAVING COUNT(DISTINCT date(ts, 'unixepoch')) >= 2
               )""").fetchone()[0]

        serves = con.execute(
            "SELECT COUNT(*), COUNT(DISTINCT user_id) FROM analytics_events"
            " WHERE event='serve'").fetchone()
        n_serves, n_servers = serves[0], serves[1]
        avg_serves = (n_serves / n_servers) if n_servers else 0.0

        tips = []
        for (props,) in con.execute(
                "SELECT props FROM analytics_events WHERE event='serve'"):
            try:
                t = json.loads(props or "{}").get("tip")
            except (json.JSONDecodeError, TypeError):
                t = None
            if isinstance(t, (int, float)):
                tips.append(t)
        avg_tip = (sum(tips) / len(tips)) if tips else None

        print(f"DB: {DB_PATH}")
        print(f"total users:            {total_users}")
        print(f"total analytics events: {total_events}")
        print("funnel:")
        print(f"  session_start:   {n_session} users")
        print(f"  ftue_done:       {n_ftue} users"
              + (f" ({n_ftue/n_session*100:.1f}% of session_start)" if n_session else ""))
        print(f"  returning (2+ UTC dates): {n_returning} users")
        print(f"avg serves per serving user: {avg_serves:.2f} ({n_serves} serves / {n_servers} users)")
        print(f"avg tip: " + (f"{avg_tip:.2f} coins over {len(tips)} tips" if avg_tip is not None else "n/a (no serve tips recorded)"))
        return 0
    except sqlite3.Error as e:
        print(f"query failed: {e}")
        return 1
    finally:
        con.close()


if __name__ == "__main__":
    sys.exit(main())
