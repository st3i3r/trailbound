#!/usr/bin/env python3
"""Permanent endpoint test suite for the café builder backend.

Stdlib only (urllib + unittest). Starts its own server instance on an
ephemeral port with an isolated temp SQLite DB, runs green, shuts down
cleanly. This is the economy's safety net: run it after any server change.

    python3 tests/test_endpoints.py
"""
import hashlib
import hmac
import json
import os
import random
import sys
import tempfile
import threading
import time
import unittest
import urllib.parse
import urllib.request
from http.server import ThreadingHTTPServer

# Isolated DB, must be set before importing the server module.
_tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_tmp.close()
os.environ["CAFE_DB"] = _tmp.name
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import server  # noqa: E402

TODO_TOKEN = "TODO_PASTE_BOT_TOKEN"  # server default when BOT_TOKEN unset
_uid_counter = [900000]


def fresh_user():
    _uid_counter[0] += 1
    return _uid_counter[0]


def mk_init_data(user_id, token=TODO_TOKEN, auth_date=None, tamper=False):
    """Craft init_data with a valid Telegram HMAC (test-only)."""
    auth_date = auth_date if auth_date is not None else int(time.time())
    params = {
        "auth_date": str(auth_date),
        "query_id": "testquery",
        "user": json.dumps({"id": user_id, "first_name": "Tester"},
                           separators=(",", ":")),
    }
    data_check = "\n".join(f"{k}={v}" for k, v in sorted(params.items()))
    secret = hmac.new(b"WebAppData", token.encode(), hashlib.sha256).digest()
    digest = hmac.new(secret, data_check.encode(), hashlib.sha256).hexdigest()
    if tamper:
        digest = ("0" if digest[0] != "0" else "1") + digest[1:]
    params["hash"] = digest
    return urllib.parse.urlencode(params)


class CafeTest(unittest.TestCase):
    base = None  # set in setUpClass

    @classmethod
    def setUpClass(cls):
        server.init_db()
        cls.srv = ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.port = cls.srv.server_address[1]
        cls.base = f"http://127.0.0.1:{cls.port}"
        cls.thread = threading.Thread(target=cls.srv.serve_forever,
                                      daemon=True)
        cls.thread.start()
        # wait for readiness
        for _ in range(50):
            try:
                r = cls.get("/healthz")
                if r[0] == 200:
                    break
            except OSError:
                time.sleep(0.1)
        else:
            raise RuntimeError("test server did not start")

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()
        cls.srv.server_close()
        try:
            os.unlink(_tmp.name)
        except OSError:
            pass

    # -- http helpers -------------------------------------------------
    @classmethod
    def get(cls, path):
        try:
            with urllib.request.urlopen(cls.base + path, timeout=10) as r:
                return r.status, json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read().decode())

    @classmethod
    def post(cls, path, body):
        req = urllib.request.Request(
            cls.base + path, data=json.dumps(body).encode(),
            headers={"Content-Type": "application/json"}, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                return r.status, json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read().decode())

    def state(self, init_data):
        code, out = self.get("/api/state?init_data=" +
                             urllib.parse.quote(init_data, safe=""))
        return code, out

    def sync(self, init_data, actions):
        return self.post("/api/sync",
                         {"init_data": init_data, "actions": actions})

    # -- tests ---------------------------------------------------------
    def test_healthz(self):
        code, out = self.get("/healthz")
        self.assertEqual(code, 200)
        self.assertTrue(out["ok"])

    def test_dev_auth_bypass(self):
        # no Telegram: local dev identity, same rules
        code, out = self.state("")
        self.assertEqual(code, 200)
        self.assertTrue(out["ok"])
        self.assertEqual(out["shop_id"], server.DEV_USER_ID)
        self.assertIn("catalog", out)
        self.assertEqual(out["ftue_step"], 0)
        self.assertFalse(out["ftue_done"])

    def test_tampered_init_data_rejected(self):
        uid = fresh_user()
        code, out = self.state(mk_init_data(uid, tamper=True))
        self.assertEqual(code, 401)
        self.assertFalse(out["ok"])

    def test_expired_init_data_rejected(self):
        uid = fresh_user()
        code, out = self.state(mk_init_data(uid, auth_date=int(time.time()) - 100000))
        self.assertEqual(code, 401)
        self.assertIn("expired", out["error"])

    def test_valid_init_data_auth(self):
        uid = fresh_user()
        code, out = self.state(mk_init_data(uid))
        self.assertEqual(code, 200)
        self.assertEqual(out["shop_id"], uid)

    def test_maya_seeded_first(self):
        uid = fresh_user()
        code, out = self.state(mk_init_data(uid))
        self.assertEqual(code, 200)
        mayas = [c for c in out["customers"] if c.get("regular") == "maya"]
        self.assertEqual(len(mayas), 1)
        self.assertEqual(mayas[0]["order"], "espresso")
        self.assertEqual(mayas[0]["name"], "Maya")

    def test_ftue_grant_once_only(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, out = self.sync(idata, [{"t": "ftue_grant"}])
        self.assertEqual(code, 200)
        self.assertTrue(out["results"][0]["ok"])
        # inventory reflects the grant
        items = {c["id"]: c for c in out["catalog"]}
        self.assertEqual(items["wooden_table"]["owned_unplaced"], 1)
        # second grant rejected (rate-limit exempt, so this is the once-only rule)
        code, out = self.sync(idata, [{"t": "ftue_grant"}])
        self.assertFalse(out["results"][0]["ok"])

    def test_ftue_step_flow(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, out = self.sync(idata, [{"t": "ftue_step", "step": 1}])
        self.assertTrue(out["results"][0]["ok"])
        self.assertEqual(out["ftue_step"], 1)
        self.assertFalse(out["ftue_done"])
        # monotonic: re-sending an earlier step does not regress
        code, out = self.sync(idata, [{"t": "ftue_step", "step": 0}])
        self.assertEqual(out["ftue_step"], 1)
        # bad step rejected
        code, out = self.sync(idata, [{"t": "ftue_step", "step": 99}])
        self.assertFalse(out["results"][0]["ok"])
        # completion
        code, out = self.sync(idata, [{"t": "ftue_step", "step": 3}])
        self.assertTrue(out["ftue_done"])

    def test_ftue_skip(self):
        uid = fresh_user()
        code, out = self.sync(mk_init_data(uid), [{"t": "ftue_skip"}])
        self.assertTrue(out["results"][0]["ok"])
        self.assertTrue(out["ftue_done"])

    def test_buy_place_move_sell(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, st = self.state(idata)
        coins0 = st["coins"]
        # batch all four mutating actions in one sync (also exercises batching)
        code, out = self.sync(idata, [
            {"t": "buy_decor", "decor": "armchair"},
            # y=1 row is empty in the starter layout
            {"t": "place", "decor": "armchair",
             "room": "main_hall", "x": 0, "y": 1},
            {"t": "move", "room": "main_hall",
             "x": 0, "y": 1, "nx": 1, "ny": 1},
            {"t": "sell", "room": "main_hall", "x": 1, "y": 1},
        ])
        self.assertEqual(code, 200)
        rs = out["results"]
        self.assertTrue(rs[0]["ok"], rs)
        self.assertTrue(rs[1]["ok"], rs)
        self.assertTrue(rs[2]["ok"], rs)
        self.assertTrue(rs[3]["ok"], rs)
        self.assertEqual(rs[3]["refund"], 15)  # 50% of 30
        # coin math: -30 (buy) + 15 (sell); checkin bonus absorbed above
        self.assertAlmostEqual(out["coins"] - coins0, -15.0, places=1)

    def test_place_overlap_rejected(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, out = self.sync(idata, [
            {"t": "buy_decor", "decor": "armchair"},
            # bar_counter occupies (0,0)-(1,0) in the starter layout
            {"t": "place", "decor": "armchair",
             "room": "main_hall", "x": 0, "y": 0},
        ])
        self.assertTrue(out["results"][0]["ok"])
        self.assertFalse(out["results"][1]["ok"])
        self.assertIn("overlap", out["results"][1]["error"])

    def test_place_oob_rejected(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, out = self.sync(idata, [
            {"t": "buy_decor", "decor": "armchair"},
            {"t": "place", "decor": "armchair",
             "room": "main_hall", "x": 8, "y": 0},
        ])
        self.assertTrue(out["results"][0]["ok"])
        self.assertFalse(out["results"][1]["ok"])

    def test_brew_discovery(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, out = self.sync(idata, [{"t": "brew",
                                       "ingredients": ["milk", "espresso"]}])
        r = out["results"][0]
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["drink"], "latte")
        self.assertTrue(r["new_recipe"])
        # recipe book now contains latte
        code, st = self.state(idata)
        learned = {x["name"] for x in st["recipes"] if x["learned"]}
        self.assertIn("latte", learned)

    def test_brew_sludge(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, out = self.sync(idata, [{"t": "brew",
                                       "ingredients": ["ice", "mint"]}])
        r = out["results"][0]
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["drink"], "sludge")
        self.assertFalse(r["new_recipe"])

    def test_brew_bad_combos_rejected(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, out = self.sync(idata, [
            {"t": "brew", "ingredients": ["a", "b", "c", "d"]},
            {"t": "brew", "ingredients": ["unobtainium"]},
        ])
        self.assertFalse(out["results"][0]["ok"])
        self.assertFalse(out["results"][1]["ok"])

    def test_serve_payout_with_coziness(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, st = self.state(idata)  # absorbs the one-time checkin bonus
        coins_before = st["coins"]
        tip_mult = st["tip_mult"]
        maya = next(c for c in st["customers"] if c.get("regular") == "maya")
        # brew her espresso (sparse starter: no brew_cut items, 4.0s base)
        code, out = self.sync(idata, [{"t": "brew", "ingredients": ["espresso"]}])
        self.assertTrue(out["results"][0]["ok"])
        time.sleep(4.0)
        code, out = self.sync(idata, [{"t": "serve", "customer": maya["cid"]}])
        r = out["results"][0]
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["event"], "happy")
        expected = round(8 + 8 * 0.2 * tip_mult, 1)  # price + tip, no evening yet
        self.assertAlmostEqual(r["payout"], expected, places=1)
        self.assertAlmostEqual(out["coins"] - coins_before, expected, places=1)
        self.assertGreater(out["rep"], st["rep"])

    def test_rate_limit_429(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, out = self.sync(idata, [{"t": "end_day"}])
        self.assertEqual(code, 200)
        code, out = self.sync(idata, [{"t": "end_day"}])
        self.assertEqual(code, 429)

    def test_visit_200_and_404(self):
        # ensure the dev user exists
        self.state("")
        code, out = self.get(f"/api/visit?shop={server.DEV_USER_ID}")
        self.assertEqual(code, 200)
        self.assertTrue(out["ok"])
        self.assertIn("rooms", out)
        code, out = self.get("/api/visit?shop=123456789")
        self.assertEqual(code, 404)

    def test_webhook_200(self):
        code, out = self.post("/api/webhook", {})
        self.assertEqual(code, 200)
        self.assertTrue(out["ok"])

    def test_invoice_400s(self):
        # unknown product
        code, out = self.post("/api/stars/invoice",
                              {"init_data": "", "product": "nope"})
        self.assertEqual(code, 400)
        # known product but no bot token configured -> clean 400, not a crash
        code, out = self.post("/api/stars/invoice",
                              {"init_data": "", "product": "golden_machine"})
        self.assertEqual(code, 400)
        self.assertFalse(out["ok"])

    def test_catalog_public(self):
        code, out = self.get("/api/catalog")
        self.assertEqual(code, 200)
        self.assertEqual(out["catalog"]["wooden_table"]["cost"], 50)
        self.assertEqual(out["catalog"]["espresso_machine"]["brew_cut"], 0.25)

    def test_ad_reward_cooldown(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, out = self.post("/api/ad/reward",
                              {"init_data": idata, "kind": "rush_hour"})
        self.assertEqual(code, 200)
        self.assertTrue(out["ok"])
        # immediate second claim -> 429 (cooldown backstop)
        code, out = self.post("/api/ad/reward",
                              {"init_data": idata, "kind": "rush_hour"})
        self.assertEqual(code, 429)


# ----------------------------------------------------------------------
# Workstreams A+B: sparse starter + economy guardrails (appended 2026-10-10)
# ----------------------------------------------------------------------

class _GuardrailBase(unittest.TestCase):
    """Own server + isolated DB per subclass. server.DB_PATH is bound at
    import time, so it is repointed explicitly here (and restored after)."""
    base = None

    @classmethod
    def setUpClass(cls):
        tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        tmp.close()
        cls._db_file = tmp.name
        cls._prev_db = server.DB_PATH
        server.DB_PATH = tmp.name
        server.init_db()
        cls.srv = ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.port = cls.srv.server_address[1]
        cls.base = f"http://127.0.0.1:{cls.port}"
        cls.thread = threading.Thread(target=cls.srv.serve_forever,
                                      daemon=True)
        cls.thread.start()
        for _ in range(50):
            try:
                code, _ = cls.get("/healthz")
                if code == 200:
                    break
            except OSError:
                time.sleep(0.1)
        else:
            raise RuntimeError("test server did not start")

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()
        cls.srv.server_close()
        server.DB_PATH = cls._prev_db
        try:
            os.unlink(cls._db_file)
        except OSError:
            pass

    @classmethod
    def get(cls, path):
        try:
            with urllib.request.urlopen(cls.base + path, timeout=10) as r:
                return r.status, json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read().decode())

    @classmethod
    def post(cls, path, body):
        req = urllib.request.Request(
            cls.base + path, data=json.dumps(body).encode(),
            headers={"Content-Type": "application/json"}, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                return r.status, json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read().decode())

    def state(self, init_data):
        code, out = self.get("/api/state?init_data=" +
                             urllib.parse.quote(init_data, safe=""))
        return code, out

    def sync(self, init_data, actions):
        return self.post("/api/sync",
                         {"init_data": init_data, "actions": actions})

    def mutate_db(self, user_id, fn):
        """Direct state manipulation between HTTP calls (test-only)."""
        with server._db_lock, server.db() as con:
            st = server.load_state(con, user_id, "Tester", time.time())
            fn(st)
            server.save_state(con, st)


class StarterSparseTest(_GuardrailBase):
    def test_starter_coziness_is_15(self):
        uid = fresh_user()
        code, st = self.state(mk_init_data(uid))
        self.assertEqual(code, 200)
        # bar_counter 6 + wooden_table 5 + armchair 4 — earned, not granted
        self.assertEqual(st["coziness"], 15)

    def test_starter_layout_no_overlaps_and_three_seats(self):
        uid = fresh_user()
        code, st = self.state(mk_init_data(uid))
        hall = next(r for r in st["rooms"] if r["id"] == "main_hall")
        self.assertEqual(len(hall["grid"]), 3)
        cells = []
        seats = 0
        for p in hall["grid"]:
            spec = server.CATALOG[p["decor"]]
            for dx in range(spec.get("w", 1)):
                for dy in range(spec.get("h", 1)):
                    cell = (p["x"] + dx, p["y"] + dy)
                    self.assertNotIn(cell, cells, f"overlap at {cell}")
                    cells.append(cell)
            seats += spec.get("seats", 0)
        self.assertEqual(seats, 3)  # Maya + 2 early customers

    def test_locked_rooms_unchanged(self):
        uid = fresh_user()
        code, st = self.state(mk_init_data(uid))
        locked = {r["id"]: r for r in st["rooms"] if not r["unlocked"]}
        self.assertEqual(set(locked), {"terrace", "lounge"})
        for r in locked.values():
            self.assertEqual(r["grid"], [])

    def test_maya_gate_is_earned_not_granted(self):
        # PRODUCTION_PLAN §2: Maya becomes a regular at coziness >= 20.
        # The sparse starter (15) must NOT satisfy it at spawn.
        uid = fresh_user()
        code, st = self.state(mk_init_data(uid))
        self.assertLess(st["coziness"], 20)
        # FTUE flow intact: Maya is still seeded as the first customer.
        mayas = [c for c in st["customers"] if c.get("regular") == "maya"]
        self.assertEqual(len(mayas), 1)

    def test_ftue_table_lands_at_17_5(self):
        # The FTUE grant is a 2nd wooden_table -> duplicate penalty (0.5x),
        # so the tutorial beat yields 15 + 2.5 = 17.5: progress, not a handout.
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        code, out = self.sync(idata, [
            {"t": "ftue_grant"},
            # sparse starter leaves (3,1) free
            {"t": "place", "decor": "wooden_table", "room": "main_hall",
             "x": 3, "y": 1},
        ])
        self.assertTrue(out["results"][0]["ok"], out["results"])
        self.assertTrue(out["results"][1]["ok"], out["results"])
        self.assertAlmostEqual(out["coziness"], 17.5)


class SoftCapTest(_GuardrailBase):
    def _big_state(self, decor, n, extra=None):
        grid = [{"decor": decor, "x": i, "y": 0} for i in range(n)]
        if extra:
            grid.append(extra)
        return {"rooms": [{"id": "main_hall", "unlocked": True,
                           "grid": grid}]}

    def test_patience_mult_capped_at_1_75(self):
        # 40 chandeliers: 12 * (1 + 0.5 + 0.25*38) = 132 effective cozy
        st = self._big_state("crystal_chandelier", 40)
        self.assertEqual(server.coziness(st), 132)
        self.assertEqual(server.patience_mult(st), 1.75)  # was 2.32 uncapped

    def test_tip_mult_cozy_part_capped_bonus_additive(self):
        st = self._big_state("crystal_chandelier", 40,
                             extra={"decor": "chalk_menu", "x": 99, "y": 0})
        # cozy = 132 + 3 = 135 -> cozy part min(1 + 135/80, 2.0) = 2.0,
        # chalk_menu tip_bonus 0.05 stays additive on top.
        self.assertEqual(server.coziness(st), 135)
        self.assertAlmostEqual(server.tip_mult(st), 2.05)
        self.assertEqual(server.patience_mult(st), 1.75)

    def test_caps_do_not_bite_early_game(self):
        uid = fresh_user()
        code, st = self.state(mk_init_data(uid))
        self.assertAlmostEqual(st["patience_mult"], 1.15, places=2)
        self.assertAlmostEqual(st["tip_mult"], 1.19, places=2)  # 1 + 15/80


class DuplicatePenaltyTest(_GuardrailBase):
    def test_three_armchairs_effective_cozy_7(self):
        st = {"rooms": [{"id": "main_hall", "unlocked": True, "grid": [
            {"decor": "armchair", "x": 0, "y": 0},
            {"decor": "armchair", "x": 1, "y": 0},
            {"decor": "armchair", "x": 2, "y": 0}]}]}
        self.assertEqual(server.coziness(st), 7)  # 4 + 2 + 1

    def test_penalty_counts_unlocked_rooms_only(self):
        st = {"rooms": [
            {"id": "main_hall", "unlocked": True, "grid": [
                {"decor": "armchair", "x": 0, "y": 0}]},
            {"id": "terrace", "unlocked": False, "grid": [
                {"decor": "armchair", "x": 0, "y": 0},
                {"decor": "armchair", "x": 1, "y": 0},
                {"decor": "armchair", "x": 2, "y": 0}]},
        ]}
        # locked room ignored: only the 1st copy counts -> 4
        self.assertEqual(server.coziness(st), 4)

    def test_penalty_end_to_end_via_place(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        code, out = self.sync(idata, [
            {"t": "buy_decor", "decor": "armchair"},
            {"t": "buy_decor", "decor": "armchair"},
            {"t": "place", "decor": "armchair", "room": "main_hall",
             "x": 2, "y": 1},
            {"t": "place", "decor": "armchair", "room": "main_hall",
             "x": 3, "y": 1},
        ])
        for r in out["results"]:
            self.assertTrue(r["ok"], out["results"])
        # starter 15 already holds armchair copy #1 (4); copies #2/#3 add 2+1
        self.assertEqual(out["coziness"], 18)


class IngredientStockTest(_GuardrailBase):
    def test_new_user_stock_full(self):
        uid = fresh_user()
        code, st = self.state(mk_init_data(uid))
        self.assertEqual(st["stock"],
                         {i: 30 for i in server.INGREDIENTS})

    def test_brew_consumes_stock(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        code, out = self.sync(idata, [{"t": "brew",
                                       "ingredients": ["espresso", "milk"]}])
        r = out["results"][0]
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["drink"], "latte")
        self.assertEqual(out["stock"]["espresso"], 29)
        self.assertEqual(out["stock"]["milk"], 29)
        self.assertEqual(out["stock"]["ice"], 30)

    def test_out_of_stock_rejected(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self.mutate_db(uid, lambda st: st["stock"].update({"espresso": 0}))
        code, out = self.sync(idata, [{"t": "brew",
                                       "ingredients": ["espresso"]}])
        r = out["results"][0]
        self.assertFalse(r["ok"])
        self.assertIn("out of stock", r["error"])
        self.assertIsNone(out["pending_brew"])  # failed brew touches nothing
        self.assertEqual(out["stock"]["espresso"], 0)

    def test_restock_costs_20_and_refills(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, st = self.state(idata)
        coins0 = st["coins"]
        self.mutate_db(uid, lambda st: st["stock"].update(
            {"espresso": 0, "milk": 5}))
        code, out = self.sync(idata, [{"t": "restock"}])
        r = out["results"][0]
        self.assertTrue(r["ok"], r)
        self.assertTrue(all(v == 30 for v in out["stock"].values()))
        self.assertAlmostEqual(out["coins"], coins0 - 20, places=1)

    def test_restock_rejected_when_broke(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self.mutate_db(uid, lambda st: st.update({"coins": 5.0}))
        code, out = self.sync(idata, [{"t": "restock"}])
        r = out["results"][0]
        self.assertFalse(r["ok"])
        self.assertIn("not enough coins", r["error"])
        self.assertAlmostEqual(out["coins"], 5.0, places=1)

    def test_rollover_resets_stock(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self.mutate_db(uid, lambda st: st["stock"].update({"espresso": 3}))
        code, out = self.sync(idata, [{"t": "end_day"}])
        self.assertTrue(out["results"][0]["ok"])
        self.assertTrue(all(v == 30 for v in out["stock"].values()))
        self.assertEqual(out["day"], 2)

    def test_old_save_gets_default_stock(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)  # creates the row
        # simulate a pre-stock save: blank the column value
        with server._db_lock, server.db() as con:
            con.execute("UPDATE users SET stock='' WHERE user_id=?", (uid,))
        code, out = self.state(idata)
        self.assertEqual(code, 200)
        self.assertTrue(all(v == 30 for v in out["stock"].values()))


# ----------------------------------------------------------------------
# Workstream G: analytics foundation (appended 2026-10-10)
# ----------------------------------------------------------------------

class AnalyticsTest(_GuardrailBase):
    """Own server + isolated DB (inherits _GuardrailBase setUpClass)."""

    def analytics(self, init_data, events):
        return self.post("/api/analytics",
                         {"init_data": init_data, "events": events})

    def query_events(self, user_id):
        with server._db_lock, server.db() as con:
            return con.execute(
                "SELECT ts, event, props FROM analytics_events"
                " WHERE user_id=? ORDER BY id", (user_id,)).fetchall()

    def test_valid_batch_mixed_events_stored(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        before = time.time()
        code, out = self.analytics(idata, [
            {"event": "session_start", "ts": 1234.5,
             "props": {"source": "ftue"}},
            {"event": "place_decor", "props": {"decor_id": "wooden_table"}},
            {"event": "quest_complete"},
        ])
        after = time.time()
        self.assertEqual(code, 200)
        self.assertTrue(out["ok"])
        self.assertEqual(out["accepted"], 3)
        self.assertEqual(out["truncated"], 0)
        rows = self.query_events(uid)
        self.assertEqual(len(rows), 3)
        self.assertEqual([r["event"] for r in rows],
                         ["session_start", "place_decor", "quest_complete"])
        # explicit ts kept; missing ts defaults to call time
        self.assertEqual(rows[0]["ts"], 1234.5)
        for r in rows[1:]:
            self.assertGreaterEqual(r["ts"], before)
            self.assertLessEqual(r["ts"], after)
        self.assertEqual(json.loads(rows[0]["props"]),
                         {"source": "ftue"})
        self.assertEqual(json.loads(rows[1]["props"]),
                         {"decor_id": "wooden_table"})
        self.assertEqual(json.loads(rows[2]["props"]), {})

    def test_tampered_init_data_401(self):
        uid = fresh_user()
        code, out = self.analytics(mk_init_data(uid, tamper=True),
                                   [{"event": "x"}])
        self.assertEqual(code, 401)
        self.assertFalse(out["ok"])
        # nothing written
        self.assertEqual(len(self.query_events(uid)), 0)

    def test_missing_events_400(self):
        uid = fresh_user()
        code, out = self.post("/api/analytics",
                              {"init_data": mk_init_data(uid)})
        self.assertEqual(code, 400)
        self.assertFalse(out["ok"])

    def test_non_list_events_400(self):
        uid = fresh_user()
        code, out = self.analytics(mk_init_data(uid), {"event": "x"})
        self.assertEqual(code, 400)

    def test_oversize_batch_capped_at_200(self):
        uid = fresh_user()
        events = [{"event": f"e{i}", "props": {"i": i}} for i in range(250)]
        code, out = self.analytics(mk_init_data(uid), events)
        self.assertEqual(code, 200)
        self.assertEqual(out["accepted"], 200)
        self.assertEqual(out["truncated"], 50)
        rows = self.query_events(uid)
        self.assertEqual(len(rows), 200)
        # first 200 kept, in order
        self.assertEqual(rows[0]["event"], "e0")
        self.assertEqual(rows[-1]["event"], "e199")

    def test_invalid_items_skipped(self):
        uid = fresh_user()
        code, out = self.analytics(mk_init_data(uid), [
            {"event": "good"},
            {"noevent": True},                    # no event key
            {"event": 123},                        # non-string event
            {"event": "   "},                      # blank event
            "just a string",                       # non-dict item
            42,                                    # non-dict item
            None,                                  # non-dict item
            {"event": "also_good", "ts": "soon",   # bad ts -> now
             "props": ["not", "a", "dict"]},       # bad props -> {}
        ])
        self.assertEqual(code, 200)
        self.assertEqual(out["accepted"], 2)
        rows = self.query_events(uid)
        self.assertEqual([r["event"] for r in rows],
                         ["good", "also_good"])
        self.assertEqual(json.loads(rows[1]["props"]), {})


# ----------------------------------------------------------------------
# Workstreams D+E: telegraphed rushes, Elena the critic, daily quests
# (appended 2026-10-10)
# ----------------------------------------------------------------------

class RushCycleTest(_GuardrailBase):
    def _sched(self, uid, **kw):
        def setup(st):
            st["customers"] = []
            st["next_spawn_at"] = time.time() + 1000  # no spawn noise
            st["rush_sched"].update(kw)
        self.mutate_db(uid, setup)

    def _types(self, out):
        return [e["type"] for e in out["events"]]

    def test_telegraph_then_active_then_end(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)  # create the row
        now = time.time()

        # 1. past the telegraph point -> rush_telegraph fires (60s warning)
        self._sched(uid, next_telegraph_at=now - 5, telegraphed=False,
                    active_until=0.0)
        code, out = self.state(idata)
        self.assertEqual(code, 200)
        self.assertIn("rush_telegraph", self._types(out))
        self.assertFalse(out["rush"]["active"])
        self.assertEqual(out["rush"]["telegraph_in"], 0)
        self.assertGreater(out["rush"]["ends_in"], 200)

        # 2. 60s lead elapsed -> rush_start, active for the 180s window
        self._sched(uid, next_telegraph_at=time.time() - 70)
        code, out = self.state(idata)
        self.assertIn("rush_start", self._types(out))
        self.assertTrue(out["rush"]["active"])
        self.assertIsNone(out["rush"]["telegraph_in"])
        self.assertGreater(out["rush"]["ends_in"], 150)
        self.assertLessEqual(out["rush"]["ends_in"], 170)

        # 3. window ends -> rush_end, next telegraph ~360s out
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            st["rush_sched"]["active_until"] = time.time() - 1
            server.save_state(con, st)
        code, out = self.state(idata)
        self.assertIn("rush_end", self._types(out))
        self.assertFalse(out["rush"]["active"])
        self.assertEqual(out["rush"]["ends_in"], 0)
        self.assertGreater(out["rush"]["telegraph_in"], 350)
        self.assertLessEqual(out["rush"]["telegraph_in"], 360)

    def test_spawn_interval_modifiers(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)

        def advance_with(**kw):
            now = time.time()
            with server._db_lock, server.db() as con:
                st = server.load_state(con, uid, "Tester", now)
                st["customers"] = []
                st["rep"] = 3.0
                st["rush_until"] = 0.0
                st["surge_until"] = 0.0
                st["rush_sched"]["active_until"] = 0.0
                st["rush_sched"]["telegraphed"] = False
                for k in kw:
                    if k == "organic_active":
                        st["rush_sched"]["active_until"] = now + 100
                    elif k == "ad_rush":
                        st["rush_until"] = now + 100
                    elif k == "surge":
                        st["surge_until"] = now + 100
                st["next_spawn_at"] = now
                server.advance(st, now)
                return st["next_spawn_at"] - now

        d_base = advance_with()
        d_organic = advance_with(organic_active=True)
        d_ad = advance_with(ad_rush=True)
        d_surge = advance_with(surge=True)
        # base ~= 25/(0.5+3/5) = 22.7s; organic and ad rushes halve it
        self.assertAlmostEqual(d_organic * 2, d_base, delta=10)
        self.assertAlmostEqual(d_ad * 2, d_base, delta=10)
        # critic surge: interval x0.75
        self.assertAlmostEqual(d_surge, d_base * 0.75, delta=6)


class CriticTest(_GuardrailBase):
    def _book_elena(self, uid):
        """Force Elena's visit to right now; return after one state tick."""
        def setup(st):
            st["customers"] = []
            st["critic"] = {"day": st["day"], "at": time.time() - 1,
                            "done": False, "history": []}
        self.mutate_db(uid, setup)

    def _elena(self, out):
        crits = [c for c in out["customers"] if c.get("is_critic")]
        self.assertEqual(len(crits), 1)
        return crits[0]

    def test_elena_scheduled_and_spawned(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._book_elena(uid)
        code, out = self.state(idata)
        self.assertEqual(code, 200)
        e = self._elena(out)
        self.assertEqual(e["name"], "Elena Voss")
        self.assertEqual(e["avatar"], "\U0001f9d0")
        self.assertEqual(e["critic_label"], "Elena Voss \u00b7 Food Critic")
        self.assertIn(e["order"], server.RECIPES)
        self.assertEqual(e["patience_max"], 45)
        self.assertLessEqual(e["patience_left"], 45)
        # critic_arrived event fired
        types = [x["type"] for x in out["events"]]
        self.assertIn("critic_arrived", types)

    def test_no_elena_below_3_rep(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)

        def setup(st):
            st["rep"] = 2.5
            st["critic"] = {"day": -1, "at": 0.0, "done": False,
                            "history": []}
        self.mutate_db(uid, setup)
        code, out = self.state(idata)
        crits = [c for c in out["customers"] if c.get("is_critic")]
        self.assertEqual(crits, [])

    def _serve_elena(self, uid, idata, cozy_setup=None):
        """Book Elena, brew her exact order, serve it fast. Returns
        (serve_result, public_state)."""
        if cozy_setup:
            self.mutate_db(uid, cozy_setup)
        self._book_elena(uid)
        code, out = self.state(idata)
        elena = self._elena(out)
        combo = list(server.RECIPES[elena["order"]]["combo"])
        code, out = self.sync(idata, [{"t": "brew", "ingredients": combo}])
        self.assertTrue(out["results"][0]["ok"], out["results"])
        # skip the brew timer (rate limit still needs its 2s)
        def ready(st):
            st["pending_brew"]["ready_at"] = time.time() - 1
        self.mutate_db(uid, ready)
        time.sleep(2.2)
        code, out = self.sync(idata, [{"t": "serve",
                                       "customer": elena["cid"]}])
        return out["results"][0], out

    def test_perfect_serve_scores_4_card_and_surge(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        r, out = self._serve_elena(uid, idata)
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["event"], "happy")
        # 2 base + correct drink + fast; cozy 15 < 40 -> 4 stars
        types = [(x["type"], x.get("score")) for x in out["events"]]
        self.assertIn(("critic_scored", 4), types)
        self.assertAlmostEqual(out["rep"], 3.3, places=2)
        self.assertEqual(out["cards"], ["elena_card_d1"])
        self.assertTrue(out["surge_active"])

    def test_perfect_serve_cozy_cafe_scores_5(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)

        def cozy(st):
            hall = next(r for r in st["rooms"] if r["id"] == "main_hall")
            extra = [("neon_sign", 0, 2), ("paper_lantern", 1, 2),
                     ("hanging_ivy", 2, 2), ("potted_fern", 3, 2),
                     ("poster", 4, 2), ("chalk_menu", 5, 2),
                     ("bookshelf", 6, 2), ("cozy_rug", 0, 4)]
            for did, x, y in extra:
                hall["grid"].append({"decor": did, "x": x, "y": y})
        r, out = self._serve_elena(uid, idata, cozy_setup=cozy)
        self.assertTrue(r["ok"], r)
        self.assertGreaterEqual(out["coziness"], 40)
        types = [(x["type"], x.get("score")) for x in out["events"]]
        self.assertIn(("critic_scored", 5), types)
        self.assertAlmostEqual(out["rep"], 3.3, places=2)
        self.assertEqual(out["cards"], ["elena_card_d1"])

    def test_walkout_scores_1_rep_down(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._book_elena(uid)
        code, out = self.state(idata)
        elena = self._elena(out)

        def expire(st):
            for c in st["customers"]:
                if c.get("is_critic"):
                    c["deadline"] = time.time() - 1
        self.mutate_db(uid, expire)
        code, out = self.state(idata)
        crits = [c for c in out["customers"] if c.get("is_critic")]
        self.assertEqual(crits, [])  # she left
        types = [(x["type"], x.get("score")) for x in out["events"]]
        self.assertIn(("critic_scored", 1), types)
        # scathing review: -0.25, and NOT the generic -0.15 on top
        self.assertAlmostEqual(out["rep"], 2.75, places=2)

    def test_wrong_drink_scores_3(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._book_elena(uid)
        code, out = self.state(idata)
        elena = self._elena(out)
        # brew a valid drink that is NOT her order
        wrong = next(n for n in server.RECIPES if n != elena["order"])
        combo = list(server.RECIPES[wrong]["combo"])
        code, out = self.sync(idata, [{"t": "brew", "ingredients": combo}])
        self.assertTrue(out["results"][0]["ok"], out["results"])

        def ready(st):
            st["pending_brew"]["ready_at"] = time.time() - 1
        self.mutate_db(uid, ready)
        time.sleep(2.2)
        code, out = self.sync(idata, [{"t": "serve",
                                       "customer": elena["cid"]}])
        r = out["results"][0]
        self.assertTrue(r["ok"], r)
        # 2 base + 0 wrong drink + 1 fast + 0 cozy = 3 -> +0.05 rep
        types = [(x["type"], x.get("score")) for x in out["events"]]
        self.assertIn(("critic_scored", 3), types)
        self.assertAlmostEqual(out["rep"], 3.05, places=2)
        self.assertEqual(out["cards"], [])


class QuestTest(_GuardrailBase):
    def _apply(self, uid, action):
        """Run one action directly against stored state (no rate limit)."""
        h = server.Handler.__new__(server.Handler)
        now = time.time()
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", now)
            r = h._apply_action(st, action, now)
            server.save_state(con, st)
        return r

    def _quest(self, out, qid):
        return next(x for x in out["quests"] if x["id"] == qid)

    def test_quests_assigned_three_per_day(self):
        uid = fresh_user()
        code, out = self.state(mk_init_data(uid))
        self.assertEqual(code, 200)
        self.assertEqual(len(out["quests"]), 3)
        for q in out["quests"]:
            for k in ("id", "desc", "target", "reward", "progress",
                      "claimed", "done"):
                self.assertIn(k, q)
            self.assertFalse(q["claimed"])
            self.assertFalse(q["done"])
            # rep_35 derives from live rep (3.0 -> 30); the rest start at 0
            if q["id"] == "rep_35":
                self.assertEqual(q["progress"], 30)
            else:
                self.assertEqual(q["progress"], 0)
        # deterministic per day: seeded by the day number
        expected = [d["id"] for d in
                    random.Random(1).sample(server.QUEST_DEFS, 3)]
        self.assertEqual([q["id"] for q in out["quests"]], expected)

    def test_progress_tracks_serve_place_brew(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, st = self.state(idata)
        maya = next(c for c in st["customers"] if c.get("regular") == "maya")
        # 1. brew + serve Maya's espresso: serve_8=1, tips_60>0
        code, out = self.sync(idata, [{"t": "brew",
                                       "ingredients": ["espresso"]}])
        self.assertTrue(out["results"][0]["ok"], out["results"])
        self.mutate_db(uid, lambda s: s["pending_brew"].update(
            {"ready_at": time.time() - 1}))
        time.sleep(2.2)
        code, out = self.sync(idata, [{"t": "serve",
                                       "customer": maya["cid"]}])
        self.assertTrue(out["results"][0]["ok"], out["results"])
        time.sleep(2.2)
        # 2. discover latte + buy/place an armchair at free (2,1)
        code, out = self.sync(idata, [
            {"t": "brew", "ingredients": ["milk", "espresso"]},
            {"t": "buy_decor", "decor": "armchair"},
            {"t": "place", "decor": "armchair", "room": "main_hall",
             "x": 2, "y": 1},
        ])
        for r in out["results"]:
            self.assertTrue(r["ok"], out["results"])
        code, out = self.state(idata)
        ids = [q["id"] for q in out["quests"]]
        if "serve_8" in ids:
            self.assertEqual(self._quest(out, "serve_8")["progress"], 1)
            self.assertFalse(self._quest(out, "serve_8")["done"])
        if "tips_60" in ids:
            self.assertGreater(self._quest(out, "tips_60")["progress"], 0)
        if "place_3" in ids:
            self.assertEqual(self._quest(out, "place_3")["progress"], 1)
        if "discover_1" in ids:
            q = self._quest(out, "discover_1")
            self.assertEqual(q["progress"], 1)
            self.assertTrue(q["done"])
        # rep_35 derives from rep: 3.08 -> 30, not done; force 3.5 -> done
        if "rep_35" in ids:
            self.assertFalse(self._quest(out, "rep_35")["done"])
            self.mutate_db(uid, lambda s: s.update({"rep": 3.5}))
            code, out = self.state(idata)
            self.assertTrue(self._quest(out, "rep_35")["done"])

    def test_claim_pays_once_and_validates(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, st0 = self.state(idata)
        coins0 = st0["coins"]
        # unknown quest
        r = self._apply(uid, {"t": "quest_claim", "quest": "nope"})
        self.assertFalse(r["ok"])
        # incomplete quest
        r = self._apply(uid, {"t": "quest_claim", "quest": "serve_8"})
        self.assertFalse(r["ok"])
        self.assertIn("not complete", r["error"])
        # complete serve_8, claim pays the reward exactly once
        self.mutate_db(uid, lambda s: s.update({"served_today": 8}))
        r = self._apply(uid, {"t": "quest_claim", "quest": "serve_8"})
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["reward"], 40)
        r2 = self._apply(uid, {"t": "quest_claim", "quest": "serve_8"})
        self.assertFalse(r2["ok"])
        self.assertIn("already claimed", r2["error"])
        code, st1 = self.state(idata)
        self.assertAlmostEqual(st1["coins"] - coins0, 40.0, places=1)

    def test_rollover_resets_quests_and_counters(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)

        def dirty(st):
            st.update({"served_today": 5, "earned_today": 123.4,
                       "tips_today": 10.0, "placed_today": 2,
                       "discovered_today": 1})
        self.mutate_db(uid, dirty)
        code, out = self.sync(idata, [{"t": "end_day"}])
        self.assertTrue(out["results"][0]["ok"], out["results"])
        self.assertEqual(out["day"], 2)
        self.assertEqual(len(out["quests"]), 3)
        for q in out["quests"]:
            # counter-derived quests reset; rep_35 derives from live rep
            # (3.0 -> 30), which a day change does not touch
            if q["id"] == "rep_35":
                self.assertEqual(q["progress"], 30)
            else:
                self.assertEqual(q["progress"], 0)
            self.assertFalse(q["claimed"])
            self.assertFalse(q["done"])
        # a fresh trio is dealt for day 2 (seeded by day number)
        expected = [d["id"] for d in
                    random.Random(2).sample(server.QUEST_DEFS, 3)]
        self.assertEqual([q["id"] for q in out["quests"]], expected)


# ----------------------------------------------------------------------
# Wave 1: content volume — 23 decor (17 -> 40), 6 drinks (6 -> 12),
# set assignment, arc/recipe unlock contract (appended 2026-10-10)
# ----------------------------------------------------------------------

class Wave1ContentTest(_GuardrailBase):
    """Own server + isolated DB (inherits _GuardrailBase setUpClass)."""

    def _apply(self, uid, action):
        """Run one action directly against stored state (no rate limit)."""
        h = server.Handler.__new__(server.Handler)
        now = time.time()
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", now)
            r = h._apply_action(st, action, now)
            server.save_state(con, st)
        return r

    def _rich(self, uid, coins=1000.0):
        self.mutate_db(uid, lambda st: st.update({"coins": coins}))

    # -- catalog integrity -------------------------------------------
    def test_catalog_has_41_entries(self):
        # 40 (Wave 1) + friendship-fern (Wave 2 referral trophy)
        self.assertEqual(len(server.CATALOG), 41)

    def test_every_non_premium_entry_has_set(self):
        for did, spec in server.CATALOG.items():
            if spec["cat"] == "premium":
                self.assertNotIn("set", spec, did)
            elif spec.get("trophy"):
                # Wave 2: the Friendship Fern is a trophy — unlock-only,
                # deliberately in no set.
                self.assertNotIn("set", spec, did)
            else:
                self.assertIn("set", spec, did)
                self.assertIn(spec["set"],
                              {"blush-parlor", "teal-terrace", "golden-hour",
                               "botanical", "noir", "festival"}, did)

    def test_friendship_fern_is_trophy(self):
        spec = server.CATALOG["friendship-fern"]
        self.assertTrue(spec["locked"])
        self.assertTrue(spec["trophy"])
        self.assertEqual(spec["cozy"], 5)
        self.assertEqual(spec["unlock_via"], "friendship-fern")

    def test_set_assignment_matches_spec(self):
        sets = {}
        for did, spec in server.CATALOG.items():
            sets.setdefault(spec.get("set"), []).append(did)
        self.assertEqual(sorted(sets["blush-parlor"]),
                         sorted(["wooden_table", "armchair", "blush-loveseat",
                                 "round-cafe-table", "table-candle",
                                 "round-rug", "photo-wall"]))
        self.assertEqual(sorted(sets["teal-terrace"]),
                         sorted(["potted_fern", "hanging_ivy", "monstera-pot",
                                 "succulent-trio", "flower-box",
                                 "spiral-topiary", "garden-fountain"]))
        self.assertEqual(sorted(sets["golden-hour"]),
                         sorted(["paper_lantern", "neon_sign", "brass-pendant",
                                 "fairy-lights", "gold-mirror",
                                 "tile-medallion", "brass-clock"]))
        self.assertEqual(sorted(sets["botanical"]),
                         sorted(["bookshelf", "magazine-rack", "signed-edition",
                                 "wall-sconce", "cozy_rug"]))
        self.assertEqual(sorted(sets["noir"]),
                         sorted(["bar_counter", "espresso_machine",
                                 "coffee-cart", "menu-board", "chalk_menu"]))
        self.assertEqual(sorted(sets["festival"]),
                         sorted(["pastry-case", "window-booth",
                                 "upright-piano", "poster"]))

    def test_arc_locked_items_have_unlock_path(self):
        for did in ("brass-clock", "signed-edition"):
            spec = server.CATALOG[did]
            self.assertTrue(spec["locked"])
            self.assertNotIn("pack", spec)  # NOT the Stars premium pack
            self.assertEqual(spec["cost"], 0)
            self.assertTrue(spec["unlock_via"])
            self.assertTrue(spec["unlock_hint"])

    def test_new_item_specs_match_wave1_tuning(self):
        expect = {
            "round-cafe-table": (45, 4, 1, 1, 2),
            "blush-loveseat": (80, 7, 2, 1, 2),
            "window-booth": (110, 8, 2, 1, 2),
            "upright-piano": (300, 9, 2, 1, 0),
            "garden-fountain": (400, 14, 2, 2, 0),
            "round-rug": (55, 5, 2, 2, 0),
            "succulent-trio": (20, 2, 1, 1, 0),
            "table-candle": (25, 3, 1, 1, 0),
        }
        for did, (cost, cozy, w, h, seats) in expect.items():
            spec = server.CATALOG[did]
            self.assertEqual(spec["cost"], cost, did)
            self.assertEqual(spec["cozy"], cozy, did)
            self.assertEqual((spec["w"], spec["h"]), (w, h), did)
            self.assertEqual(spec.get("seats", 0), seats, did)
        self.assertEqual(server.CATALOG["pastry-case"]["tip_bonus"], 0.05)
        self.assertEqual(server.CATALOG["upright-piano"]["tip_bonus"], 0.05)
        self.assertEqual(server.CATALOG["menu-board"]["tip_bonus"], 0.05)
        self.assertEqual(server.CATALOG["coffee-cart"]["brew_cut"], 0.05)

    # -- buy/place one of every new category --------------------------
    def test_buy_place_each_new_category(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._rich(uid)
        code, out = self.sync(idata, [
            {"t": "buy_decor", "decor": "round-cafe-table"},   # furniture
            {"t": "place", "decor": "round-cafe-table",
             "room": "main_hall", "x": 0, "y": 1},
            {"t": "buy_decor", "decor": "monstera-pot"},       # plants
            {"t": "place", "decor": "monstera-pot",
             "room": "main_hall", "x": 1, "y": 1},
            {"t": "buy_decor", "decor": "brass-pendant"},      # lighting
            {"t": "place", "decor": "brass-pendant",
             "room": "main_hall", "x": 2, "y": 1},
            {"t": "buy_decor", "decor": "gold-mirror"},        # wall
            {"t": "place", "decor": "gold-mirror",
             "room": "main_hall", "x": 3, "y": 1},
            {"t": "buy_decor", "decor": "round-rug"},          # floor
            {"t": "place", "decor": "round-rug",
             "room": "main_hall", "x": 0, "y": 3},
        ])
        self.assertEqual(code, 200)
        for i, r in enumerate(out["results"]):
            self.assertTrue(r["ok"], (i, out["results"]))
        # coziness grew: 4+5+5+6+5 = 25 new cozy on the 15 starter
        self.assertEqual(out["coziness"], 40)
        # seats grew by round-cafe-table's 2
        hall = next(r for r in out["rooms"] if r["id"] == "main_hall")
        placed = {p["decor"] for p in hall["grid"]}
        for did in ("round-cafe-table", "monstera-pot", "brass-pendant",
                    "gold-mirror", "round-rug"):
            self.assertIn(did, placed)

    def test_new_seating_serves_customers(self):
        # round-cafe-table seats 2: customers can be seated on it
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._rich(uid)
        r = self._apply(uid, {"t": "buy_decor",
                              "decor": "round-cafe-table"})
        self.assertTrue(r["ok"], r)
        r = self._apply(uid, {"t": "place", "decor": "round-cafe-table",
                              "room": "main_hall", "x": 0, "y": 1})
        self.assertTrue(r["ok"], r)
        seat = server.free_seat(server.load_state(
            server.db(), uid, "Tester", time.time()))
        self.assertIsNotNone(seat)

    # -- arc-locked decor unlock contract ------------------------------
    def test_arc_decor_locked_until_granted(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        # buy rejected while locked (zero-cost, so this is the lock talking)
        r = self._apply(uid, {"t": "buy_decor", "decor": "brass-clock"})
        self.assertFalse(r["ok"])
        self.assertIn("story arc", r["error"])
        # place rejected too, even with a smuggled inventory copy
        self.mutate_db(uid, lambda st: st["inventory"].update(
            {"signed-edition": 1}))
        r = self._apply(uid, {"t": "place", "decor": "signed-edition",
                              "room": "main_hall", "x": 4, "y": 1})
        self.assertFalse(r["ok"])
        self.assertIn("story arc", r["error"])
        # public catalog marks both locked
        code, out = self.state(idata)
        items = {c["id"]: c for c in out["catalog"]}
        self.assertTrue(items["brass-clock"]["locked"])
        self.assertTrue(items["signed-edition"]["locked"])
        # grant via the Wave-2 mechanism -> buy + place work, still free
        self.mutate_db(uid, lambda st: server.grant_decor_unlock(
            st, "brass-clock"))
        coins_before = out["coins"]
        r = self._apply(uid, {"t": "buy_decor", "decor": "brass-clock"})
        self.assertTrue(r["ok"], r)
        r = self._apply(uid, {"t": "place", "decor": "brass-clock",
                              "room": "main_hall", "x": 4, "y": 1})
        self.assertTrue(r["ok"], r)
        code, out = self.state(idata)
        self.assertFalse({c["id"]: c for c in out["catalog"]}
                         ["brass-clock"]["locked"])
        self.assertAlmostEqual(out["coins"], coins_before, places=1)
        self.assertEqual(out["coziness"], 15 + 8)

    def test_premium_lock_unchanged_by_arc_mechanism(self):
        # premium pack still gated the old way
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        r = self._apply(uid, {"t": "buy_decor", "decor": "velvet_sofa"})
        self.assertFalse(r["ok"])
        self.assertIn("premium pack", r["error"])

    # -- recipe locks ----------------------------------------------------
    def test_recipe_combos_unique(self):
        combos = [r["combo"] for r in server.RECIPES.values()]
        self.assertEqual(len(combos), len(set(combos)))
        self.assertEqual(len(server.RECIPES), 12)

    def test_new_drinks_discoverable(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        cases = {
            ("chocolate", "milk"): "hot_chocolate",
            ("caramel", "espresso"): "caramel_espresso",
            ("espresso", "mint"): "mint_espresso",
            ("espresso", "milk", "mint"): "mint_latte",
            ("chocolate", "espresso", "ice"): "iced_mocha",
        }
        for combo, drink in cases.items():
            r = self._apply(uid, {"t": "brew",
                                  "ingredients": list(combo)})
            self.assertTrue(r["ok"], (combo, r))
            self.assertEqual(r["drink"], drink, combo)
            self.assertTrue(r["new_recipe"], combo)
        code, out = self.state(idata)
        learned = {x["name"] for x in out["recipes"] if x["learned"]}
        for drink in cases.values():
            self.assertIn(drink, learned)

    def test_nightingale_locked_brews_sludge_no_learn(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        combo = ["caramel", "chocolate", "espresso"]
        r = self._apply(uid, {"t": "brew", "ingredients": combo})
        self.assertTrue(r["ok"], r)
        # the signature sludge outcome: no learning, no leak
        self.assertEqual(r["drink"], "sludge")
        self.assertFalse(r["new_recipe"])
        code, out = self.state(idata)
        learned = {x["name"] for x in out["recipes"] if x["learned"]}
        self.assertNotIn("nightingale", learned)
        entry = next(x for x in out["recipes"] if x["name"] == "nightingale")
        self.assertTrue(entry["locked"])
        self.assertEqual(entry["combo"], [])
        self.assertIn("???", entry["display"])
        # unlock via the Wave-2 mechanism -> the same combo now discovers it
        self.mutate_db(uid, lambda st: server.grant_recipe_unlock(
            st, "nightingale"))
        r = self._apply(uid, {"t": "brew", "ingredients": combo})
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["drink"], "nightingale")
        self.assertTrue(r["new_recipe"])
        code, out = self.state(idata)
        entry = next(x for x in out["recipes"] if x["name"] == "nightingale")
        self.assertFalse(entry["locked"])
        self.assertEqual(entry["combo"], list(combo))
        self.assertEqual(entry["price"], 22)

    def test_nightingale_never_ordered_or_hinted_while_locked(self):
        uid = fresh_user()
        self.state(mk_init_data(uid))

        def setup(st):
            st["customers"] = []
            st["next_spawn_at"] = time.time() + 1000
        self.mutate_db(uid, setup)
        now = time.time()
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", now)
            for _ in range(60):
                server.spawn_customer(st, now)
            orders = {c["order"] for c in st["customers"]}
            server.save_state(con, st)
        self.assertNotIn("nightingale", orders)
        # hint never leaks the locked recipe: with every open recipe learned,
        # the hint action reports everything known instead of nightingale
        self.mutate_db(uid, lambda st: st.update(
            {"recipes": [n for n in server.RECIPES
                         if n not in server.RECIPE_LOCKS]}))
        h = server.Handler.__new__(server.Handler)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            r = h._a_hint(st)
            server.save_state(con, st)
        self.assertFalse(r["ok"])
        self.assertIn("all recipes known", r["error"])

    def test_locked_recipes_retargeted_to_season_2(self):
        by_name = {e["name"]: e for e in server.LOCKED_RECIPES}
        self.assertEqual(by_name["flat_white"]["hint"], "Season 2 menu")
        self.assertEqual(by_name["affogato"]["hint"], "Season 2 menu")

    # -- FTUE / starter untouched ----------------------------------------
    def test_starter_layout_ids_unchanged(self):
        uid = fresh_user()
        code, out = self.state(mk_init_data(uid))
        hall = next(r for r in out["rooms"] if r["id"] == "main_hall")
        self.assertEqual({p["decor"] for p in hall["grid"]},
                         {"bar_counter", "wooden_table", "armchair"})
        mayas = [c for c in out["customers"] if c.get("regular") == "maya"]
        self.assertEqual(len(mayas), 1)
        self.assertEqual(mayas[0]["order"], "espresso")


# ----------------------------------------------------------------------
# Wave 2: progression (C), narrative arcs (D), social (E)
# (appended 2026-10-10)
# ----------------------------------------------------------------------

class Wave2Test(_GuardrailBase):
    """Own server + isolated DB (inherits _GuardrailBase setUpClass)."""

    def _apply(self, uid, action):
        """Run one action directly against stored state (no rate limit)."""
        h = server.Handler.__new__(server.Handler)
        now = time.time()
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", now)
            r = h._apply_action(st, action, now)
            server.save_state(con, st)
        return r

    def _w2(self, uid):
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            return st["w2"]

    def _post_ftue(self, uid):
        """Brand-new user straight past the tutorial (arcs need ftue_done)."""
        self.mutate_db(uid, lambda st: (
            st.update({"ftue_done": 1, "ftue_step": 3}),
            st.update({"customers": []}),
            st.update({"next_spawn_at": time.time() + 1000})))

    def _seat(self, uid, reg=None, order="espresso", cid=None, name="Walker"):
        """Seat one deterministic customer (regular or walk-in)."""
        def setup(st):
            st["customers"] = []
            st["next_spawn_at"] = time.time() + 1000
            spec = server.REGULARS.get(reg, {}) if reg else {}
            st["customers"].append({
                "cid": cid or f"t-{reg or 'walk'}-{int(time.time()*1000)}",
                "name": spec.get("name", name),
                "avatar": spec.get("avatar", "\U0001f468"),
                "order": order, "deadline": time.time() + 3600,
                "room": "main_hall", "sx": 3, "sy": 0, "seat": 0,
                **({"regular": reg} if reg else {}),
            })
        self.mutate_db(uid, setup)
        return (cid or f"t-{reg or 'walk'}-{int(time.time()*1000)}")

    def _serve(self, uid, cid, ingredients, slow_s=0):
        """Brew + force the timer + serve, direct (no rate limit).
        slow_s>0 backdates ready_at so the serve looks that many seconds
        after brew-ready (Chen's <20s chain)."""
        h = server.Handler.__new__(server.Handler)
        now = time.time()
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", now)
            r = h._apply_action(
                st, {"t": "brew", "ingredients": ingredients}, now)
            assert r["ok"], r
            st["pending_brew"]["ready_at"] = now - 1 - slow_s
            r2 = h._apply_action(st, {"t": "serve", "customer": cid}, now)
            server.save_state(con, st)
        return r2

    def _rich(self, uid, coins=5000.0):
        self.mutate_db(uid, lambda st: st.update({"coins": coins}))

    def _add_table(self, uid):
        """Append a 2-seat round-cafe-table on a free 1x1 tile (test-only).
        Event waves (viral/ward) need 4+ free seats to fill the spawn cap."""
        def setup(st):
            hall = next(r for r in st["rooms"] if r["id"] == "main_hall")
            taken = set()
            for p in hall["grid"]:
                s = server.CATALOG[p["decor"]]
                for dx in range(s.get("w", 1)):
                    for dy in range(s.get("h", 1)):
                        taken.add((p["x"] + dx, p["y"] + dy))
            for y in range(6):
                for x in range(8):
                    if (x, y) not in taken:
                        hall["grid"].append(
                            {"decor": "round-cafe-table", "x": x, "y": y})
                        return
        self.mutate_db(uid, setup)

    # -- C.1 café levels ------------------------------------------------
    def test_level_thresholds(self):
        self.assertEqual(server.level_threshold(1), 20)
        self.assertEqual(server.level_threshold(2), 60)
        self.assertEqual(server.level_threshold(3), 120)
        self.assertEqual(server.level_threshold(30), 9300)

    def test_serve_awards_xp(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self._seat(uid, reg="maya", order="espresso", cid="c-xp")
        r = self._serve(uid, "c-xp", ["espresso"])
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["event"], "happy")
        # tip ~1.9 >= 1 -> 1 + 1 = 2 XP
        self.assertEqual(self._w2(uid)["xp"], 2)
        self.assertEqual(self._w2(uid)["level"], 1)

    def test_level_up_grants_coins(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        code, st0 = self.state(idata)
        coins0 = st0["coins"]
        self.mutate_db(uid, lambda st: st["w2"].update({"xp": 59}))
        self._seat(uid, reg="maya", order="espresso", cid="c-lv")
        r = self._serve(uid, "c-lv", ["espresso"])
        self.assertTrue(r["ok"], r)
        w2 = self._w2(uid)
        self.assertEqual(w2["level"], 2)
        self.assertEqual(w2["xp"], 61)
        # level-up reward: 25*2 = 50 coins on top of the serve payout
        code, st1 = self.state(idata)
        self.assertGreaterEqual(st1["coins"] - coins0 - r["payout"], 49.9)
        # the modal goes through the levelups queue (client clears it)
        self.assertEqual(len(st1["levelups"]), 1)
        self.assertEqual(st1["levelups"][0]["level"], 2)
        self.assertEqual(st1["levelups"][0]["coins"], 50)
        r = self._apply(uid, {"t": "levelups_seen"})
        self.assertTrue(r["ok"], r)
        code, st2 = self.state(idata)
        self.assertEqual(st2["levelups"], [])
        # public state exposes the progression triple
        self.assertEqual(st1["level"], 2)
        self.assertEqual(st1["xp"], 61)
        self.assertEqual(st1["xp_next"], server.level_threshold(3))

    def test_level_5_grants_set_decor(self):
        uid = fresh_user()
        self.state(mk_init_data(uid))
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["w2"].update(
            {"level": 4, "xp": server.level_threshold(5) - 1}))
        self._seat(uid, reg="maya", order="espresso", cid="c-lv5")
        r = self._serve(uid, "c-lv5", ["espresso"])
        self.assertTrue(r["ok"], r)
        w2 = self._w2(uid)
        self.assertEqual(w2["level"], 5)
        evs = [e for e in self._last_events(uid) if e["type"] == "level_reward"]
        self.assertEqual(len(evs), 1)
        did = evs[0]["decor"]
        spec = server.CATALOG[did]
        self.assertIn("set", spec)          # from a real set...
        self.assertFalse(spec.get("locked"))  # ...buyable, not arc/premium
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            self.assertGreaterEqual(st["inventory"].get(did, 0), 1)

    def _last_events(self, uid):
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            return list(st["events"])

    def test_levelup_modal_queued_during_ftue(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)  # ftue NOT done
        self.mutate_db(uid, lambda st: st["w2"].update({"xp": 59}))
        self._seat(uid, reg="maya", order="espresso", cid="c-ftue")
        # note: _seat does not set ftue_done; arcs stay dormant, XP applies
        r = self._serve(uid, "c-ftue", ["espresso"])
        self.assertTrue(r["ok"], r)
        w2 = self._w2(uid)
        self.assertEqual(w2["level"], 2)
        self.assertEqual(len(w2["pending_levelups"]), 1)
        self.assertEqual(w2["pending_levelups"][0]["level"], 2)
        # suppressed from public state while the FTUE runs...
        code, out = self.state(idata)
        self.assertEqual(out["levelups"], [])
        types = [e["type"] for e in out["events"]]
        self.assertNotIn("level_up", types)
        # ...released after ftue_done, clearable by the client
        self.mutate_db(uid, lambda st: st.update({"ftue_done": 1}))
        code, out = self.state(idata)
        self.assertEqual(len(out["levelups"]), 1)
        self.assertEqual(out["levelups"][0]["level"], 2)
        r = self._apply(uid, {"t": "levelups_seen"})
        self.assertTrue(r["ok"], r)
        self.assertEqual(self._w2(uid)["pending_levelups"], [])

    def test_level_cap_30(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["w2"].update(
            {"level": 30, "xp": 99999}))
        self._seat(uid, reg="maya", order="espresso", cid="c-cap")
        r = self._serve(uid, "c-cap", ["espresso"])
        self.assertTrue(r["ok"], r)
        w2 = self._w2(uid)
        self.assertEqual(w2["level"], 30)
        code, out = self.state(idata)
        self.assertIsNone(out["xp_next"])

    # -- C.2 decor set bonuses -------------------------------------------
    def _set_state(self, placements):
        return {"rooms": [{"id": "main_hall", "unlocked": True,
                           "grid": [{"decor": d, "x": i, "y": 0}
                                    for i, d in enumerate(placements)]}]}

    def test_set_bonus_math(self):
        blush = ["wooden_table", "armchair", "round-cafe-table",
                 "blush-loveseat", "table-candle", "round-rug", "photo-wall"]
        st = self._set_state(blush)
        # 5+4+4+7+3+5+4 = 32 -> x1.15 = 36.8
        self.assertEqual(server.coziness(st), 36.8)
        prog = server.set_progress(st)["blush-parlor"]
        self.assertEqual((prog["placed"], prog["total"], prog["complete"]),
                         (7, 7, True))

    def test_set_incomplete_no_bonus(self):
        blush = ["wooden_table", "armchair", "round-cafe-table",
                 "blush-loveseat", "table-candle", "round-rug"]  # 6/7
        st = self._set_state(blush)
        self.assertEqual(server.coziness(st), 28)  # 32-4, no bonus
        prog = server.set_progress(st)["blush-parlor"]
        self.assertEqual((prog["placed"], prog["total"], prog["complete"]),
                         (6, 7, False))

    def test_arc_item_gates_golden_hour(self):
        gold = ["paper_lantern", "neon_sign", "brass-pendant", "fairy-lights",
                "gold-mirror", "tile-medallion"]  # brass-clock missing
        st = self._set_state(gold)
        prog = server.set_progress(st)["golden-hour"]
        self.assertFalse(prog["complete"])
        # 4+7+5+7+6+7 = 36, no bonus
        self.assertEqual(server.coziness(st), 36)
        # unlock + place the arc item -> set completes, clock gets the bonus
        st2 = self._set_state(gold + ["brass-clock"])
        prog2 = server.set_progress(st2)["golden-hour"]
        self.assertTrue(prog2["complete"])
        # (36 + 8) * 1.15 = 50.6
        self.assertAlmostEqual(server.coziness(st2), 50.6)

    def test_set_complete_event_on_place(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self._rich(uid)
        # festival = 4 items: pastry-case, window-booth, upright-piano, poster
        code, out = self.sync(idata, [
            {"t": "buy_decor", "decor": "pastry-case"},
            {"t": "place", "decor": "pastry-case", "room": "main_hall",
             "x": 0, "y": 1},
            {"t": "buy_decor", "decor": "window-booth"},
            {"t": "place", "decor": "window-booth", "room": "main_hall",
             "x": 1, "y": 1},
            {"t": "buy_decor", "decor": "upright-piano"},
            {"t": "place", "decor": "upright-piano", "room": "main_hall",
             "x": 3, "y": 1},
            {"t": "buy_decor", "decor": "poster"},
            {"t": "place", "decor": "poster", "room": "main_hall",
             "x": 5, "y": 1},
        ])
        for i, r in enumerate(out["results"]):
            self.assertTrue(r["ok"], (i, out["results"]))
        done = [e for e in out["events"] if e["type"] == "set_complete"]
        self.assertEqual(len(done), 1)
        self.assertEqual(done[0]["set"], "festival")
        prog = out["set_progress"]["festival"]
        self.assertTrue(prog["complete"])
        self.assertEqual((prog["placed"], prog["total"]), (4, 4))
        # coziness: starter 15 + (5+8+9+2)*1.15 = 15 + 27.6 = 42.6
        self.assertAlmostEqual(out["coziness"], 42.6)

    # -- C.3 drink mastery -------------------------------------------------
    def test_mastery_tiers_and_price(self):
        self.assertEqual(server.mastery_stars(9), 0)
        self.assertEqual(server.mastery_stars(10), 1)
        self.assertEqual(server.mastery_stars(24), 1)
        self.assertEqual(server.mastery_stars(25), 2)
        self.assertEqual(server.mastery_stars(49), 2)
        self.assertEqual(server.mastery_stars(50), 3)
        uid = fresh_user()
        self.state(mk_init_data(uid))
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["w2"]["mastery"].update(
            {"espresso": 24}))
        self._seat(uid, order="espresso", cid="c-m1")
        r = self._serve(uid, "c-m1", ["espresso"])
        self.assertTrue(r["ok"], r)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            self.assertEqual(st["w2"]["mastery"]["espresso"], 25)
        evs = [e for e in self._last_events(uid)
               if e["type"] == "mastery_up"]
        self.assertEqual([(e["drink"], e["stars"]) for e in evs],
                         [("espresso", 2)])
        # next serve prices at 8 * 1.10 = 8.8
        self._seat(uid, order="espresso", cid="c-m2")
        code, st0 = self.state(mk_init_data(uid))
        tm = st0["tip_mult"]
        r = self._serve(uid, "c-m2", ["espresso"])
        expected = round(8.8 + 8.8 * 0.2 * tm, 1)
        self.assertAlmostEqual(r["payout"], expected, places=1)

    def test_mastery_only_counts_correct_serves(self):
        uid = fresh_user()
        self.state(mk_init_data(uid))
        self._post_ftue(uid)
        self._seat(uid, order="latte", cid="c-mw")  # wants latte...
        r = self._serve(uid, "c-mw", ["espresso"])  # ...gets espresso
        self.assertEqual(r["event"], "wrong")
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            self.assertEqual(st["w2"]["mastery"].get("espresso", 0), 0)

    def test_recipe_book_shows_stars(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self.mutate_db(uid, lambda st: st["w2"]["mastery"].update(
            {"espresso": 50, "latte": 12}))
        code, out = self.state(idata)
        by_name = {r["name"]: r for r in out["recipes"]}
        self.assertEqual(by_name["espresso"]["mastery"], 3)
        self.assertEqual(by_name["espresso"]["serves"], 50)
        self.assertEqual(by_name["latte"]["mastery"], 1)

    # -- D. Mr. Chen -------------------------------------------------------
    def _spawn_regular(self, uid, reg):
        """Deterministic regular spawn (mocks the 30% roll + pool pick)."""
        import unittest.mock as mock
        now = time.time()
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", now)
            with mock.patch.object(server.random, "random",
                                   return_value=0.0), \
                 mock.patch.object(server.random, "choice",
                                   side_effect=lambda xs: xs[0]):
                # force the pool to just this regular
                for r in ("maya", "chen", "zoe", "rafi"):
                    st["w2"]["arcs"][r]["pool"] = (r == reg)
                cust = server._maybe_regular_spawn(st, now)
                server.save_state(con, st)
        return cust

    def test_chen_pool_entry_and_intro(self):
        uid = fresh_user()
        self.state(mk_init_data(uid))
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["w2"].update({"serves_total": 9}))
        self.mutate_db(uid, lambda st: server._arc_tick(st, time.time()))
        self.assertFalse(self._w2(uid)["arcs"]["chen"]["pool"])
        self.mutate_db(uid, lambda st: st["w2"].update({"serves_total": 10}))
        self.mutate_db(uid, lambda st: server._arc_tick(st, time.time()))
        self.assertTrue(self._w2(uid)["arcs"]["chen"]["pool"])
        types = [e["type"] for e in self._last_events(uid)]
        self.assertIn("regular_unlocked", types)
        # first spawn -> beat 1 + stopwatch intro modal
        cust = self._spawn_regular(uid, "chen")
        self.assertIsNotNone(cust)
        self.assertEqual(cust["regular"], "chen")
        self.assertEqual(cust["order"], "espresso")
        arc = self._w2(uid)["arcs"]["chen"]
        self.assertEqual(arc["beat"], 1)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            kinds = [m["kind"] for m in st["w2"]["modal_queue"]]
        self.assertIn("chen_intro", kinds)

    def test_chen_five_fast_espressos(self):
        uid = fresh_user()
        self.state(mk_init_data(uid))
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["w2"]["arcs"]["chen"].update(
            {"pool": True, "beat": 1, "fast_chain": 0}))
        for i in range(5):
            self._seat(uid, order="espresso", cid=f"c-ch{i}")
            r = self._serve(uid, f"c-ch{i}", ["espresso"])
            self.assertTrue(r["ok"], r)
        arc = self._w2(uid)["arcs"]["chen"]
        self.assertEqual(arc["beat"], 2)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            kinds = [m["kind"] for m in st["w2"]["modal_queue"]]
        self.assertIn("chen_beat2", kinds)

    def test_chen_chain_resets(self):
        uid = fresh_user()
        self.state(mk_init_data(uid))
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["w2"]["arcs"]["chen"].update(
            {"pool": True, "beat": 1, "fast_chain": 0}))
        for i in range(2):  # two fast...
            self._seat(uid, order="espresso", cid=f"c-cr{i}")
            self._serve(uid, f"c-cr{i}", ["espresso"])
        self.assertEqual(self._w2(uid)["arcs"]["chen"]["fast_chain"], 2)
        # ...then a slow one (25s after brew-ready) resets the chain
        self._seat(uid, order="espresso", cid="c-cr-slow")
        r = self._serve(uid, "c-cr-slow", ["espresso"], slow_s=25)
        self.assertTrue(r["ok"], r)
        arc = self._w2(uid)["arcs"]["chen"]
        self.assertEqual(arc["fast_chain"], 0)
        self.assertEqual(arc["beat"], 1)
        # a wrong drink resets too
        for i in range(3):
            self._seat(uid, order="espresso", cid=f"c-cr2-{i}")
            self._serve(uid, f"c-cr2-{i}", ["espresso"])
        self._seat(uid, order="latte", cid="c-cr-wrong")
        self._serve(uid, "c-cr-wrong", ["espresso"])
        self.assertEqual(self._w2(uid)["arcs"]["chen"]["fast_chain"], 0)

    def test_chen_beat3_gifts_clock(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["w2"]["arcs"]["chen"].update(
            {"pool": True, "beat": 2}))
        self._seat(uid, reg="chen", order="espresso", cid="c-ch3")
        r = self._serve(uid, "c-ch3", ["espresso"])
        self.assertTrue(r["ok"], r)
        arc = self._w2(uid)["arcs"]["chen"]
        self.assertEqual(arc["beat"], 3)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            self.assertIn("brass-clock", st["unlocked_decor"])
            kinds = [m["kind"] for m in st["w2"]["modal_queue"]]
        self.assertIn("chen_beat3", kinds)
        # the clock is now buyable (free) and placeable
        r = self._apply(uid, {"t": "buy_decor", "decor": "brass-clock"})
        self.assertTrue(r["ok"], r)
        code, out = self.state(idata)
        items = {c["id"]: c for c in out["catalog"]}
        self.assertFalse(items["brass-clock"]["locked"])
        # golden-hour set now completable -> check via set_progress math
        self.assertEqual(out["set_progress"]["golden-hour"]["total"], 7)

    # -- D. Zoe ------------------------------------------------------------
    def _cozy_cafe(self, uid, target=40):
        """Directly place decor until coziness >= target (test-only)."""
        def setup(st):
            hall = next(r for r in st["rooms"] if r["id"] == "main_hall")
            if server.coziness(st) >= target:
                return
            for did in ("spiral-topiary", "garden-fountain", "neon_sign",
                        "upright-piano", "blush-loveseat", "fairy-lights",
                        "gold-mirror", "hanging_ivy"):
                for x in range(8):
                    for y in range(1, 6):
                        if server.coziness(st) >= target:
                            return
                        spec = server.CATALOG[did]
                        w, h = spec.get("w", 1), spec.get("h", 1)
                        if x + w > 8 or y + h > 6:
                            continue
                        clash = False
                        for p in hall["grid"]:
                            s2 = server.CATALOG[p["decor"]]
                            if not (x + w <= p["x"]
                                    or p["x"] + s2.get("w", 1) <= x
                                    or y + h <= p["y"]
                                    or p["y"] + s2.get("h", 1) <= y):
                                clash = True
                                break
                        if not clash:
                            hall["grid"].append(
                                {"decor": did, "x": x, "y": y})
                            if server.coziness(st) >= target:
                                return
        self.mutate_db(uid, setup)

    def test_zoe_pool_photo_and_viral(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        # cozy gate: 15 starter < 40 -> no pool
        self.mutate_db(uid, lambda st: server._arc_tick(st, time.time()))
        self.assertFalse(self._w2(uid)["arcs"]["zoe"]["pool"])
        self._cozy_cafe(uid, 40)
        self.mutate_db(uid, lambda st: server._arc_tick(st, time.time()))
        self.assertTrue(self._w2(uid)["arcs"]["zoe"]["pool"])
        # first spawn -> beat 1: photo modal + 100 coins
        code, st0 = self.state(idata)
        cust = self._spawn_regular(uid, "zoe")
        self.assertIsNotNone(cust)
        self.assertEqual(cust["order"], "iced_latte")
        self.assertEqual(self._w2(uid)["arcs"]["zoe"]["beat"], 1)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            kinds = [m["kind"] for m in st["w2"]["modal_queue"]]
            self.assertIn("zoe_photo", kinds)
        code, st1 = self.state(idata)
        self.assertGreaterEqual(st1["coins"] - st0["coins"], 99.9)
        # 3 correct serves -> viral crowd: 10 customers within 3 min
        for i in range(3):
            self._seat(uid, reg="zoe", order="iced_latte", cid=f"c-z{i}")
            r = self._serve(uid, f"c-z{i}", ["espresso", "milk", "ice"])
            self.assertTrue(r["ok"], r)
            self.assertEqual(r["event"], "happy")
        zarc = self._w2(uid)["arcs"]["zoe"]
        self.assertEqual(zarc["beat"], 2)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            viral = st["w2"]["viral"]
            self.assertIsNotNone(viral)
            self.assertEqual(len(viral["spawn_times"]), 10)
            self.assertLessEqual(max(viral["spawn_times"]) - time.time(), 190)
            kinds = [m["kind"] for m in st["w2"]["modal_queue"]]
            self.assertIn("zoe_viral", kinds)
        # the viral wave actually spawns customers (needs 4+ free seats)
        self._add_table(uid)
        self.mutate_db(uid, lambda st: st.update({"customers": []}))
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            v = st["w2"]["viral"]
            v["spawn_times"] = [time.time() - 1] * 10
            server.save_state(con, st)
        code, out = self.state(idata)
        # 10 scheduled, but the concurrent-customer cap holds at 4
        self.assertEqual(len(out["customers"]), 4)
    def test_zoe_brand_deal_accept(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["w2"]["arcs"]["zoe"].update(
            {"pool": True, "beat": 2}))
        # trigger the choice modal with one more correct serve
        self._seat(uid, reg="zoe", order="iced_latte", cid="c-zc")
        r = self._serve(uid, "c-zc", ["espresso", "milk", "ice"])
        self.assertTrue(r["ok"], r)
        zarc = self._w2(uid)["arcs"]["zoe"]
        self.assertTrue(zarc["choice_pending"])
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            kinds = [m["kind"] for m in st["w2"]["modal_queue"]]
            self.assertIn("zoe_choice", kinds)
            choice_modal = next(m for m in st["w2"]["modal_queue"]
                                if m["kind"] == "zoe_choice")
            self.assertEqual(len(choice_modal["choices"]), 2)
        code, st0 = self.state(idata)
        r = self._apply(uid, {"t": "arc_choice", "regular": "zoe",
                              "choice": "accept"})
        self.assertTrue(r["ok"], r)
        zarc = self._w2(uid)["arcs"]["zoe"]
        self.assertEqual((zarc["beat"], zarc["choice"]), (3, "accept"))
        w2 = self._w2(uid)
        self.assertEqual(w2["sponsored"], 1)
        self.assertGreater(w2["sponsored_until"], time.time())
        code, st1 = self.state(idata)
        self.assertGreaterEqual(st1["coins"] - st0["coins"], 799.9)
        self.assertTrue(st1["sponsored"])
        # visit card shows the 📢 poster
        code, visit = self.get(f"/api/visit?shop={uid}")
        self.assertTrue(visit["sponsored"])
        # purist regulars' patience drops 10% while sponsored
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            st["w2"]["arcs"]["maya"]["pool"] = True
            cust = {"cid": "x", "deadline": time.time() + 100,
                    "regular": "maya"}
            server._apply_sponsor(st, cust, time.time())
            self.assertAlmostEqual(cust["deadline"] - time.time(), 90,
                                   delta=2)
            cust2 = {"cid": "y", "deadline": time.time() + 100,
                     "regular": ""}
            server._apply_sponsor(st, cust2, time.time())
            self.assertAlmostEqual(cust2["deadline"] - time.time(), 100,
                                   delta=2)

    def test_zoe_brand_deal_decline(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["w2"]["arcs"]["zoe"].update(
            {"pool": True, "beat": 2, "choice_pending": True}))
        code, st0 = self.state(idata)
        r = self._apply(uid, {"t": "arc_choice", "regular": "zoe",
                              "choice": "decline"})
        self.assertTrue(r["ok"], r)
        self.assertEqual(self._w2(uid)["arcs"]["zoe"]["choice"], "decline")
        code, st1 = self.state(idata)
        self.assertAlmostEqual(st1["rep"] - st0["rep"], 0.2, places=2)
        self.assertFalse(self._w2(uid)["sponsored"])
        # no pending choice -> second choice rejected
        r = self._apply(uid, {"t": "arc_choice", "regular": "zoe",
                              "choice": "accept"})
        self.assertFalse(r["ok"])

    # -- D. Rafi -------------------------------------------------------------
    def test_rafi_arc_to_nightingale(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        # evening gate: rep < 4 -> no pool
        self.mutate_db(uid, lambda st: server._arc_tick(st, time.time()))
        self.assertFalse(self._w2(uid)["arcs"]["rafi"]["pool"])
        self.mutate_db(uid, lambda st: st.update({"rep": 4.0}))
        self.mutate_db(uid, lambda st: server._arc_tick(st, time.time()))
        self.assertTrue(self._w2(uid)["arcs"]["rafi"]["pool"])
        cust = self._spawn_regular(uid, "rafi")
        self.assertIsNotNone(cust)
        self.assertEqual(cust["order"], "mocha")  # nightingale not invented
        self.assertEqual(self._w2(uid)["arcs"]["rafi"]["beat"], 1)
        # 3 evenings (distinct in-game days) -> the Nightingale is invented
        for day in (1, 2, 3):
            self.mutate_db(uid, lambda st, d=day: st.update({"day": d}))
            self._seat(uid, reg="rafi", order="mocha", cid=f"c-r{day}")
            r = self._serve(uid, f"c-r{day}", ["espresso", "milk",
                                               "chocolate"])
            self.assertTrue(r["ok"], r)
            self.assertEqual(r["event"], "happy")
        rarc = self._w2(uid)["arcs"]["rafi"]
        self.assertEqual(rarc["beat"], 2)
        self.assertEqual(len(rarc["evenings"]), 3)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            self.assertIn("nightingale", st["recipes_unlocked"])
            kinds = [m["kind"] for m in st["w2"]["modal_queue"]]
            self.assertIn("rafi_beat2", kinds)
        # he orders the Nightingale thereafter
        cust = self._spawn_regular(uid, "rafi")
        self.assertEqual(cust["order"], "nightingale")
        # serving him the nightingale -> the ward rush (5 at once)
        self._seat(uid, reg="rafi", order="nightingale", cid="c-rw")
        r = self._serve(uid, "c-rw", ["espresso", "chocolate", "caramel"])
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["served"], "nightingale")
        self.assertEqual(self._w2(uid)["arcs"]["rafi"]["beat"], 3)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            viral = st["w2"]["viral"]
            self.assertEqual(len(viral["spawn_times"]), 5)
            self.assertEqual(viral["kind"], "rafi")
            kinds = [m["kind"] for m in st["w2"]["modal_queue"]]
            self.assertIn("rafi_ward", kinds)
        # the wave spawns mocha/nightingale orders only (needs 4+ seats)
        self._add_table(uid)
        self.mutate_db(uid, lambda st: st.update({"customers": []}))
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            st["w2"]["viral"]["spawn_times"] = [time.time() - 1] * 5
            server.save_state(con, st)
        code, out = self.state(idata)
        orders = {c["order"] for c in out["customers"]}
        self.assertTrue(orders <= {"mocha", "nightingale"})
        self.assertEqual(len(out["customers"]), 4)  # cap is 4

    def test_rafi_evening_only(self):
        # Rafi never spawns below the evening rep gate, even in the pool
        uid = fresh_user()
        self.state(mk_init_data(uid))
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: (
            st.update({"rep": 3.0}),
            st["w2"]["arcs"]["rafi"].update({"pool": True})))
        import unittest.mock as mock
        now = time.time()
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", now)
            seen_rafi = False
            with mock.patch.object(server.random, "random",
                                   return_value=0.0):
                for _ in range(20):
                    for r in ("maya", "chen", "zoe"):
                        st["w2"]["arcs"][r]["pool"] = False
                    c = server._maybe_regular_spawn(st, now)
                    if c and c["regular"] == "rafi":
                        seen_rafi = True
            self.assertFalse(seen_rafi)

    # -- D. Maya ---------------------------------------------------------------
    def test_maya_beat2_on_discovery(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["w2"]["arcs"]["maya"].update(
            {"pool": True}))
        # Maya seated; discover mint_mocha -> beat 2 fires on the tick
        self._seat(uid, reg="maya", order="latte", cid="c-mb2")
        r = self._apply(uid, {"t": "brew",
                              "ingredients": ["chocolate", "espresso",
                                              "mint"]})
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["drink"], "mint_mocha")
        self.assertTrue(r["new_recipe"])
        self.mutate_db(uid, lambda st: server._arc_tick(st, time.time()))
        marc = self._w2(uid)["arcs"]["maya"]
        self.assertEqual(marc["beat"], 2)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            kinds = [m["kind"] for m in st["w2"]["modal_queue"]]
            self.assertIn("maya_beat2", kinds)
        # her signature order evolves to mint_mocha (she must not already
        # be seated — seated regulars are excluded from the spawn pool)
        self.mutate_db(uid, lambda st: st.update({"customers": []}))
        cust = self._spawn_regular(uid, "maya")
        self.assertEqual(cust["order"], "mint_mocha")

    def test_maya_beat3_published(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: (
            st["w2"]["arcs"]["maya"].update({"pool": True, "beat": 2}),
            st["recipes"].append("mint_mocha")))
        for i in range(5):
            self._seat(uid, reg="maya", order="mint_mocha", cid=f"c-mb{i}")
            r = self._serve(uid, f"c-mb{i}",
                            ["chocolate", "espresso", "mint"])
            self.assertTrue(r["ok"], r)
            self.assertEqual(r["event"], "happy")
        marc = self._w2(uid)["arcs"]["maya"]
        self.assertEqual(marc["beat"], 3)
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            self.assertIn("signed-edition", st["unlocked_decor"])
            kinds = [m["kind"] for m in st["w2"]["modal_queue"]]
            self.assertIn("maya_beat3", kinds)

    def test_arc_modals_suppressed_until_ftue_done(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)  # ftue NOT done
        self.mutate_db(uid, lambda st: server.queue_modal(st, "chen_intro"))
        code, out = self.state(idata)
        self.assertEqual(out["arc_modals"], [])
        self.mutate_db(uid, lambda st: st.update({"ftue_done": 1}))
        code, out = self.state(idata)
        self.assertEqual(len(out["arc_modals"]), 1)
        self.assertEqual(out["arc_modals"][0]["kind"], "chen_intro")
        self.assertIn("stopwatch", out["arc_modals"][0]["text"].lower())
        r = self._apply(uid, {"t": "modals_seen"})
        self.assertTrue(r["ok"], r)
        code, out = self.state(idata)
        self.assertEqual(out["arc_modals"], [])

    # -- D. Elena arc ------------------------------------------------------------
    def _elena_score(self, uid, score):
        with server._db_lock, server.db() as con:
            st = server.load_state(con, uid, "Tester", time.time())
            server.apply_critic_score(st, {}, score, time.time())
            server.save_state(con, st)

    def test_elena_five_stars_arc(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["critic"].update(
            {"history": [{"day": 1, "score": 5}, {"day": 2, "score": 4}]}))
        code, st0 = self.state(idata)
        self._elena_score(uid, 5)
        el = self._w2(uid)["arcs"]["elena"]
        self.assertTrue(el["arc_done"])
        code, st1 = self.state(idata)
        # per-visit +0.3, arc +0.5
        self.assertAlmostEqual(st1["rep"] - st0["rep"], 0.8, places=2)
        self.assertTrue(st1["surge_active"])
        kinds = [m["kind"] for m in st1["arc_modals"]]
        self.assertIn("elena_five", kinds)
        # fires exactly once: a 4th high score is just per-visit scoring
        self._elena_score(uid, 5)
        code, st2 = self.state(idata)
        self.assertAlmostEqual(st2["rep"] - st1["rep"], 0.3, places=2)

    def test_elena_scathing_and_comeback(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["critic"].update(
            {"history": [{"day": 1, "score": 2}, {"day": 2, "score": 2}]}))
        code, st0 = self.state(idata)
        self._elena_score(uid, 3)  # 0/3 high -> scathing
        el = self._w2(uid)["arcs"]["elena"]
        self.assertTrue(el["arc_done"])
        self.assertTrue(el["comeback"])
        code, st1 = self.state(idata)
        # per-visit +0.05 (score 3), arc -0.5
        self.assertAlmostEqual(st1["rep"] - st0["rep"], -0.45, places=2)
        kinds = [m["kind"] for m in st1["arc_modals"]]
        self.assertIn("elena_scathing", kinds)
        # comeback: next visit scores double — a 2 becomes a 4 (+0.3, card)
        self._elena_score(uid, 2)
        self.assertFalse(self._w2(uid)["arcs"]["elena"]["comeback"])
        code, st2 = self.state(idata)
        types = [(e["type"], e.get("score")) for e in st2["events"]]
        self.assertIn(("comeback_used", 4), types)
        self.assertIn(("critic_scored", 4), types)
        self.assertEqual(len(st2["cards"]), 1)  # 4-star card earned

    def test_elena_mixed_two_of_three(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self._post_ftue(uid)
        self.mutate_db(uid, lambda st: st["critic"].update(
            {"history": [{"day": 1, "score": 5}, {"day": 2, "score": 5}]}))
        code, st0 = self.state(idata)
        self._elena_score(uid, 2)  # 2/3 high -> mixed, no arc outcome
        el = self._w2(uid)["arcs"]["elena"]
        self.assertTrue(el["arc_done"])
        self.assertFalse(el["comeback"])
        code, st1 = self.state(idata)
        # per-visit only: score 2 -> -0.25
        self.assertAlmostEqual(st1["rep"] - st0["rep"], -0.25, places=2)
        kinds = [m["kind"] for m in st1["arc_modals"]]
        self.assertNotIn("elena_five", kinds)
        self.assertNotIn("elena_scathing", kinds)

    # -- E.1 visit tips ------------------------------------------------------------
    def test_visit_tip_flow(self):
        host = fresh_user()
        self.state(mk_init_data(host))  # host exists
        visitors = []
        for _ in range(3):
            v = fresh_user()
            code, st = self.state(mk_init_data(v))
            self.assertEqual(code, 200)
            visitors.append((v, mk_init_data(v), st["coins"]))
        code, h0 = self.state(mk_init_data(host))
        for v, idata, coins0 in visitors:
            code, out = self.post("/api/visit/tip",
                                  {"init_data": idata, "shop_id": host})
            self.assertEqual(code, 200, out)
            self.assertTrue(out["ok"])
            self.assertEqual(out["tipped"], 10)
            code, st = self.state(idata)
            self.assertAlmostEqual(st["coins"], coins0 - 10, places=1)
        code, h1 = self.state(mk_init_data(host))
        self.assertAlmostEqual(h1["coins"] - h0["coins"], 30.0, places=1)
        # host day summary reports the tips
        code, out = self.post("/api/sync",
                              {"init_data": mk_init_data(host),
                               "actions": [{"t": "end_day"}]})
        self.assertTrue(out["results"][0]["ok"])
        self.assertEqual(out["results"][0]["day_summary"]["tips_received"],
                         30.0)
        types = [e["type"] for e in out["events"]]
        self.assertIn("tip_received", types)

    def test_visit_tip_cap_and_self_reject(self):
        host = fresh_user()
        self.state(mk_init_data(host))
        v = fresh_user()
        idata = mk_init_data(v)
        self.state(idata)
        for i in range(3):
            code, out = self.post("/api/visit/tip",
                                  {"init_data": idata, "shop_id": host})
            self.assertEqual(code, 200, (i, out))
            time.sleep(2.2)  # rate-limit spacing for the same visitor
        code, out = self.post("/api/visit/tip",
                              {"init_data": idata, "shop_id": host})
        self.assertEqual(code, 429)
        self.assertIn("cap", out["error"])
        # self-tip rejected (fresh user: no rate-limit history to confuse it)
        u2 = fresh_user()
        code, out = self.post("/api/visit/tip",
                              {"init_data": mk_init_data(u2), "shop_id": u2})
        self.assertEqual(code, 400)
        self.assertIn("own caf", out["error"])
        # unknown café (fresh user again)
        u3 = fresh_user()
        code, out = self.post("/api/visit/tip",
                              {"init_data": mk_init_data(u3),
                               "shop_id": 987654321})
        self.assertEqual(code, 404)

    # -- E.3 referral --------------------------------------------------------------
    def test_referral_double_grant(self):
        ref = fresh_user()
        self.state(mk_init_data(ref))
        new = fresh_user()
        idata = mk_init_data(new)
        # signup with ?ref=<referrer>
        code, out = self.get("/api/state?init_data=" +
                             urllib.parse.quote(idata, safe="") +
                             f"&ref={ref}")
        self.assertEqual(code, 200)
        items = {c["id"]: c for c in out["catalog"]}
        self.assertFalse(items["friendship-fern"]["locked"])
        self.assertEqual(items["friendship-fern"]["owned_unplaced"], 1)
        # the trophy is not for sale...
        r = self._apply(new, {"t": "buy_decor", "decor": "friendship-fern"})
        self.assertFalse(r["ok"])
        self.assertIn("not for sale", r["error"])
        # ...but it places fine
        r = self._apply(new, {"t": "place", "decor": "friendship-fern",
                              "room": "main_hall", "x": 0, "y": 1})
        self.assertTrue(r["ok"], r)
        # referrer gets theirs on next state load (pending grant)
        code, rout = self.state(mk_init_data(ref))
        ritems = {c["id"]: c for c in rout["catalog"]}
        self.assertEqual(ritems["friendship-fern"]["owned_unplaced"], 1)
        types = [e["type"] for e in rout["events"]]
        self.assertIn("referral_grant", types)
        # no double grant on later loads
        code, rout2 = self.state(mk_init_data(ref))
        ritems2 = {c["id"]: c for c in rout2["catalog"]}
        self.assertEqual(ritems2["friendship-fern"]["owned_unplaced"], 1)
        # self-referral and unknown refs grant nothing
        sneaky = fresh_user()
        sidata = mk_init_data(sneaky)
        code, out = self.get("/api/state?init_data=" +
                             urllib.parse.quote(sidata, safe="") +
                             f"&ref={sneaky}")
        items = {c["id"]: c for c in out["catalog"]}
        self.assertTrue(items["friendship-fern"]["locked"])
        code, out = self.get("/api/state?init_data=" +
                             urllib.parse.quote(sidata, safe="") +
                             "&ref=987654321")
        items = {c["id"]: c for c in out["catalog"]}
        self.assertTrue(items["friendship-fern"]["locked"])

    # -- E.4 leaderboard ------------------------------------------------------------
    def test_leaderboard_opt_in_and_rank(self):
        users = []
        for earned in (500.0, 1500.0, 100.0):
            u = fresh_user()
            self.state(mk_init_data(u))
            self.mutate_db(u, lambda st, e=earned: (
                st["w2"].update({"lb_opt_in": 1, "weekly_earned": e})))
            users.append(u)
        # fourth user: not opted in, high earnings -> excluded
        ghost = fresh_user()
        self.state(mk_init_data(ghost))
        self.mutate_db(ghost, lambda st: st["w2"].update(
            {"lb_opt_in": 0, "weekly_earned": 99999.0}))
        code, out = self.get("/api/leaderboard?init_data=" +
                             urllib.parse.quote(mk_init_data(users[0]),
                                                safe=""))
        self.assertEqual(code, 200)
        self.assertTrue(out["ok"])
        self.assertEqual(len(out["board"]), 3)
        self.assertEqual([e["weekly_earned"] for e in out["board"]],
                         [1500.0, 500.0, 100.0])
        self.assertTrue(out["board"][1]["you"])
        self.assertTrue(out["opt_in"])
        # toggle off -> disappears
        r = self._apply(users[0], {"t": "lb_opt_in", "on": False})
        self.assertTrue(r["ok"], r)
        code, out = self.state(mk_init_data(users[0]))
        self.assertFalse(out["lb_opt_in"])
        code, out = self.get("/api/leaderboard?init_data=" +
                             urllib.parse.quote(mk_init_data(users[1]),
                                                safe=""))
        self.assertEqual(len(out["board"]), 2)
        # stale week bucket counts as 0
        self.mutate_db(users[1], lambda st: st["w2"].update({"week": "2000-W01"}))
        code, out = self.get("/api/leaderboard?init_data=" +
                             urllib.parse.quote(mk_init_data(users[1]),
                                                safe=""))
        top = next(e for e in out["board"] if e["you"])
        self.assertEqual(top["weekly_earned"], 0.0)

    def test_weekly_bucket_resets(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        self.state(idata)
        self.mutate_db(uid, lambda st: st["w2"].update(
            {"week": "2000-W01", "weekly_earned": 123.0}))
        code, out = self.state(idata)
        self.assertEqual(out["weekly_earned"], 0.0)
        self.assertEqual(self._w2(uid)["week"], server._iso_week(time.time()))

    def test_public_state_wave2_shape(self):
        uid = fresh_user()
        idata = mk_init_data(uid)
        code, out = self.state(idata)
        self.assertEqual(code, 200)
        for k in ("level", "xp", "xp_next", "levelups", "set_progress",
                  "arcs", "elena_arc", "maya_hint", "arc_modals", "sponsored",
                  "lb_opt_in", "weekly_earned"):
            self.assertIn(k, out, k)
        self.assertEqual(out["level"], 1)
        self.assertEqual(out["xp"], 0)
        self.assertEqual(out["xp_next"], 60)
        self.assertEqual(set(out["set_progress"]),
                         {"blush-parlor", "teal-terrace", "golden-hour",
                          "botanical", "noir", "festival"})
        self.assertEqual(set(out["arcs"]),
                         {"maya", "chen", "zoe", "rafi"})


if __name__ == "__main__":
    unittest.main(verbosity=2)

