import os
import json
from datetime import datetime, timedelta
from functools import wraps

import psycopg2
import psycopg2.extras
from flask import Flask, render_template, request, jsonify, Response
from werkzeug.middleware.proxy_fix import ProxyFix

app = Flask(__name__)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "postgres"),
    "port": int(os.environ.get("DB_PORT", 5432)),
    "dbname": os.environ.get("DB_NAME", "n8n"),
    "user": os.environ.get("DB_USER", "n8n"),
    "password": os.environ.get("DB_PASSWORD", "n8n_secret"),
}

ADMIN_USER = os.environ.get("ADMIN_USER", "admin")
ADMIN_PASS = os.environ.get("ADMIN_PASSWORD", "changeme")


def get_db():
    return psycopg2.connect(**DB_CONFIG)


def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.authorization
        if not auth or auth.username != ADMIN_USER or auth.password != ADMIN_PASS:
            return Response(
                "Authentication required",
                401,
                {"WWW-Authenticate": 'Basic realm="Admin"'},
            )
        return f(*args, **kwargs)
    return decorated


def query_db(sql, params=None, fetchone=False):
    conn = get_db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            if sql.strip().upper().startswith(("SELECT", "WITH")):
                return cur.fetchone() if fetchone else cur.fetchall()
            conn.commit()
            if cur.description:
                return cur.fetchone() if fetchone else cur.fetchall()
            return {"affected": cur.rowcount}
    finally:
        conn.close()


def execute_db(sql, params=None):
    conn = get_db()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            conn.commit()
            return {"affected": cur.rowcount}
    finally:
        conn.close()


# ============================================
# PAGES
# ============================================

@app.route("/")
@require_auth
def index():
    return render_template("index.html")


# ============================================
# DASHBOARD API
# ============================================

@app.route("/api/dashboard")
@require_auth
def api_dashboard():
    balance = query_db(
        "SELECT balance, spend_rate_per_hour, hours_remaining, collected_at "
        "FROM balance_history ORDER BY collected_at DESC LIMIT 1",
        fetchone=True,
    )
    emergency = query_db(
        "SELECT is_active, trigger_reason, activated_at, auto_deactivate_at "
        "FROM emergency_state WHERE is_active = TRUE ORDER BY activated_at DESC LIMIT 1",
        fetchone=True,
    )
    today = datetime.now().strftime("%Y-%m-%d")
    today_stats = query_db(
        "SELECT COUNT(*) as total_ads, "
        "SUM(money) as total_spend, "
        "SUM(postbacks_confirmed_money) as total_revenue, "
        "SUM(profit) as total_profit "
        "FROM ad_stats WHERE date = %s",
        (today,),
        fetchone=True,
    )
    teaser_counts = query_db(
        "SELECT state, COUNT(*) as cnt FROM teasers GROUP BY state"
    )
    bid_changes_24h = query_db(
        "SELECT COUNT(*) as cnt FROM bid_history WHERE changed_at >= NOW() - INTERVAL '24 hours'",
        fetchone=True,
    )
    anomalies_open = query_db(
        "SELECT COUNT(*) as cnt FROM anomalies WHERE resolved = FALSE",
        fetchone=True,
    )
    conservative = query_db(
        "SELECT locked_by, expires_at FROM workflow_locks "
        "WHERE lock_name = 'conservative_mode' AND expires_at > NOW()",
        fetchone=True,
    )
    return jsonify({
        "balance": _serialize(balance),
        "emergency": _serialize(emergency),
        "today_stats": _serialize(today_stats),
        "teaser_counts": _serialize(teaser_counts),
        "bid_changes_24h": _serialize(bid_changes_24h),
        "anomalies_open": _serialize(anomalies_open),
        "conservative_mode": _serialize(conservative),
    })


# ============================================
# CONFIG API (bot_config table)
# ============================================

@app.route("/api/config")
@require_auth
def api_config_list():
    rows = query_db(
        "SELECT id, category, key, value, value_type, label, description, "
        "min_value, max_value, updated_at FROM bot_config ORDER BY category, id"
    )
    grouped = {}
    for r in rows:
        cat = r["category"]
        if cat not in grouped:
            grouped[cat] = []
        grouped[cat].append(_serialize(r))
    return jsonify(grouped)


@app.route("/api/config/<int:config_id>", methods=["PUT"])
@require_auth
def api_config_update(config_id):
    data = request.get_json()
    new_value = str(data.get("value", "")).strip()
    if not new_value:
        return jsonify({"error": "Value is required"}), 400

    row = query_db("SELECT * FROM bot_config WHERE id = %s", (config_id,), fetchone=True)
    if not row:
        return jsonify({"error": "Config not found"}), 404

    if row["value_type"] in ("number", "integer"):
        try:
            float(new_value)
        except ValueError:
            return jsonify({"error": "Invalid number"}), 400
        if row["min_value"] is not None and float(new_value) < float(row["min_value"]):
            return jsonify({"error": f"Value below minimum ({row['min_value']})"}), 400
        if row["max_value"] is not None and float(new_value) > float(row["max_value"]):
            return jsonify({"error": f"Value above maximum ({row['max_value']})"}), 400

    execute_db(
        "UPDATE bot_config SET value = %s, updated_at = NOW() WHERE id = %s",
        (new_value, config_id),
    )
    return jsonify({"ok": True, "id": config_id, "value": new_value})


@app.route("/api/config/bulk", methods=["PUT"])
@require_auth
def api_config_bulk_update():
    data = request.get_json()
    updates = data.get("updates", [])
    errors = []
    for u in updates:
        cid = u.get("id")
        val = str(u.get("value", "")).strip()
        if not cid or not val:
            continue
        row = query_db("SELECT * FROM bot_config WHERE id = %s", (cid,), fetchone=True)
        if not row:
            errors.append(f"Config {cid} not found")
            continue
        if row["value_type"] in ("number", "integer"):
            try:
                float(val)
            except ValueError:
                errors.append(f"Config {cid}: invalid number")
                continue
            if row["min_value"] is not None and float(val) < float(row["min_value"]):
                errors.append(f"Config {cid}: below minimum")
                continue
            if row["max_value"] is not None and float(val) > float(row["max_value"]):
                errors.append(f"Config {cid}: above maximum")
                continue
        execute_db(
            "UPDATE bot_config SET value = %s, updated_at = NOW() WHERE id = %s",
            (val, cid),
        )
    return jsonify({"ok": True, "errors": errors})


# ============================================
# GEO PAYOUTS API
# ============================================

@app.route("/api/geo_payouts")
@require_auth
def api_geo_payouts():
    rows = query_db(
        "SELECT id, country_code, country_name, geo_id, vertical, "
        "avg_payout, avg_approval, max_cpl, min_bid, max_bid, is_active, notes, updated_at "
        "FROM geo_payouts ORDER BY country_code"
    )
    return jsonify(_serialize(rows))


@app.route("/api/geo_payouts/<int:geo_id>", methods=["PUT"])
@require_auth
def api_geo_payout_update(geo_id):
    data = request.get_json()
    fields = ["avg_payout", "avg_approval", "min_bid", "max_bid", "is_active", "notes", "country_name", "geo_id", "vertical"]
    sets = []
    params = []
    for f in fields:
        if f in data:
            sets.append(f"{f} = %s")
            params.append(data[f])
    if not sets:
        return jsonify({"error": "No fields to update"}), 400
    sets.append("updated_at = NOW()")
    params.append(geo_id)
    execute_db(f"UPDATE geo_payouts SET {', '.join(sets)} WHERE id = %s", params)
    return jsonify({"ok": True})


@app.route("/api/geo_payouts", methods=["POST"])
@require_auth
def api_geo_payout_create():
    data = request.get_json()
    required = ["country_code", "country_name", "avg_payout", "avg_approval"]
    for r in required:
        if r not in data:
            return jsonify({"error": f"Missing field: {r}"}), 400
    execute_db(
        "INSERT INTO geo_payouts (country_code, country_name, geo_id, vertical, "
        "avg_payout, avg_approval, min_bid, max_bid, is_active, notes) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s) "
        "ON CONFLICT (country_code) DO UPDATE SET "
        "country_name=EXCLUDED.country_name, geo_id=EXCLUDED.geo_id, "
        "avg_payout=EXCLUDED.avg_payout, avg_approval=EXCLUDED.avg_approval, "
        "min_bid=EXCLUDED.min_bid, max_bid=EXCLUDED.max_bid, "
        "is_active=EXCLUDED.is_active, notes=EXCLUDED.notes, updated_at=NOW()",
        (
            data["country_code"], data["country_name"],
            data.get("geo_id"), data.get("vertical", "crypto"),
            data["avg_payout"], data["avg_approval"],
            data.get("min_bid", 0.01), data.get("max_bid", 0.15),
            data.get("is_active", True), data.get("notes"),
        ),
    )
    return jsonify({"ok": True})


@app.route("/api/geo_payouts/<int:geo_id>", methods=["DELETE"])
@require_auth
def api_geo_payout_delete(geo_id):
    execute_db("DELETE FROM geo_payouts WHERE id = %s", (geo_id,))
    return jsonify({"ok": True})


# ============================================
# TEASERS API
# ============================================

@app.route("/api/teasers")
@require_auth
def api_teasers():
    limit = int(request.args.get("limit", 100))
    offset = int(request.args.get("offset", 0))
    state = request.args.get("state")
    where = ""
    params = []
    if state:
        where = "WHERE t.state = %s"
        params.append(state)
    params.extend([limit, offset])
    rows = query_db(
        f"SELECT t.*, "
        f"s.money as today_spend, s.clicks as today_clicks, s.roi as today_roi, "
        f"s.ctr as today_ctr, s.postbacks_count as today_leads "
        f"FROM teasers t "
        f"LEFT JOIN ad_stats s ON s.ad_id = t.ad_id AND s.date = CURRENT_DATE "
        f"{where} "
        f"ORDER BY t.updated_at DESC LIMIT %s OFFSET %s",
        params,
    )
    total = query_db(
        f"SELECT COUNT(*) as cnt FROM teasers t {where}",
        params[:1] if state else None,
        fetchone=True,
    )
    return jsonify({"data": _serialize(rows), "total": total["cnt"] if total else 0})


@app.route("/api/teasers/<int:teaser_id>/state", methods=["PUT"])
@require_auth
def api_teaser_state(teaser_id):
    data = request.get_json()
    new_state = data.get("state")
    reason = data.get("reason", "Manual change via admin UI")
    if new_state not in ("active", "paused", "stopped", "testing", "created"):
        return jsonify({"error": "Invalid state"}), 400

    old = query_db("SELECT state, ad_id FROM teasers WHERE id = %s", (teaser_id,), fetchone=True)
    if not old:
        return jsonify({"error": "Teaser not found"}), 404

    execute_db(
        "UPDATE teasers SET state = %s, state_changed_at = NOW(), state_reason = %s, updated_at = NOW() WHERE id = %s",
        (new_state, reason, teaser_id),
    )
    execute_db(
        "INSERT INTO teaser_state_log (teaser_id, ad_id, old_state, new_state, reason, triggered_by) "
        "VALUES (%s, %s, %s, %s, %s, 'admin_ui')",
        (teaser_id, old["ad_id"], old["state"], new_state, reason),
    )
    return jsonify({"ok": True})


# ============================================
# BID HISTORY API
# ============================================

@app.route("/api/bid_history")
@require_auth
def api_bid_history():
    limit = int(request.args.get("limit", 100))
    ad_id = request.args.get("ad_id")
    where = ""
    params = []
    if ad_id:
        where = "WHERE ad_id = %s"
        params.append(int(ad_id))
    params.append(limit)
    rows = query_db(
        f"SELECT * FROM bid_history {where} ORDER BY changed_at DESC LIMIT %s",
        params,
    )
    return jsonify(_serialize(rows))


# ============================================
# ANOMALIES API
# ============================================

@app.route("/api/anomalies")
@require_auth
def api_anomalies():
    resolved = request.args.get("resolved", "false")
    limit = int(request.args.get("limit", 100))
    rows = query_db(
        "SELECT * FROM anomalies WHERE resolved = %s ORDER BY detected_at DESC LIMIT %s",
        (resolved == "true", limit),
    )
    return jsonify(_serialize(rows))


@app.route("/api/anomalies/<int:anomaly_id>/resolve", methods=["PUT"])
@require_auth
def api_anomaly_resolve(anomaly_id):
    execute_db(
        "UPDATE anomalies SET resolved = TRUE, resolved_at = NOW() WHERE id = %s",
        (anomaly_id,),
    )
    return jsonify({"ok": True})


# ============================================
# EMERGENCY CONTROL API
# ============================================

@app.route("/api/emergency")
@require_auth
def api_emergency():
    state = query_db(
        "SELECT * FROM emergency_state ORDER BY activated_at DESC LIMIT 5"
    )
    return jsonify(_serialize(state))


@app.route("/api/emergency/activate", methods=["POST"])
@require_auth
def api_emergency_activate():
    data = request.get_json()
    reason = data.get("reason", "Manual activation via admin UI")
    hours = float(data.get("auto_deactivate_hours", 2))
    execute_db(
        "INSERT INTO emergency_state (is_active, trigger_reason, triggered_by, activated_at, auto_deactivate_at) "
        "VALUES (TRUE, %s, 'admin_ui', NOW(), NOW() + INTERVAL '%s hours') "
        "ON CONFLICT (is_active) WHERE is_active = TRUE "
        "DO UPDATE SET trigger_reason = EXCLUDED.trigger_reason, activated_at = NOW(), "
        "auto_deactivate_at = NOW() + make_interval(hours => %s)",
        (reason, hours, hours),
    )
    return jsonify({"ok": True})


@app.route("/api/emergency/deactivate", methods=["POST"])
@require_auth
def api_emergency_deactivate():
    execute_db(
        "UPDATE emergency_state SET is_active = FALSE, deactivated_at = NOW() WHERE is_active = TRUE"
    )
    return jsonify({"ok": True})


@app.route("/api/conservative/activate", methods=["POST"])
@require_auth
def api_conservative_activate():
    data = request.get_json()
    minutes = int(data.get("minutes", 30))
    execute_db(
        "INSERT INTO workflow_locks (lock_name, locked_by, expires_at) "
        "VALUES ('conservative_mode', 'admin_ui', NOW() + make_interval(mins => %s)) "
        "ON CONFLICT (lock_name) DO UPDATE SET locked_by = 'admin_ui', locked_at = NOW(), "
        "expires_at = NOW() + make_interval(mins => %s)",
        (minutes, minutes),
    )
    return jsonify({"ok": True})


@app.route("/api/conservative/deactivate", methods=["POST"])
@require_auth
def api_conservative_deactivate():
    execute_db("DELETE FROM workflow_locks WHERE lock_name = 'conservative_mode'")
    return jsonify({"ok": True})


# ============================================
# DAILY PNL API
# ============================================

@app.route("/api/daily_pnl")
@require_auth
def api_daily_pnl():
    limit = int(request.args.get("limit", 30))
    rows = query_db(
        "SELECT * FROM daily_pnl ORDER BY date DESC LIMIT %s", (limit,)
    )
    return jsonify(_serialize(rows))


# ============================================
# ACCOUNTS API
# ============================================

@app.route("/api/accounts")
@require_auth
def api_accounts():
    rows = query_db("SELECT * FROM accounts ORDER BY id")
    return jsonify(_serialize(rows))


@app.route("/api/accounts/<int:account_id>", methods=["PUT"])
@require_auth
def api_account_update(account_id):
    data = request.get_json()
    fields = ["name", "status", "daily_budget", "notes"]
    sets = []
    params = []
    for f in fields:
        if f in data:
            sets.append(f"{f} = %s")
            params.append(data[f])
    if not sets:
        return jsonify({"error": "No fields"}), 400
    sets.append("updated_at = NOW()")
    params.append(account_id)
    execute_db(f"UPDATE accounts SET {', '.join(sets)} WHERE id = %s", params)
    return jsonify({"ok": True})


# ============================================
# BLOCK LISTS API
# ============================================

@app.route("/api/block_lists")
@require_auth
def api_block_lists():
    list_type = request.args.get("type")
    limit = int(request.args.get("limit", 200))
    where = ""
    params = []
    if list_type:
        where = "WHERE list_type = %s"
        params.append(list_type)
    params.append(limit)
    rows = query_db(
        f"SELECT * FROM block_lists {where} ORDER BY added_at DESC LIMIT %s",
        params,
    )
    return jsonify(_serialize(rows))


@app.route("/api/block_lists/<int:bl_id>", methods=["DELETE"])
@require_auth
def api_block_list_delete(bl_id):
    execute_db("DELETE FROM block_lists WHERE id = %s", (bl_id,))
    return jsonify({"ok": True})


# ============================================
# SCAN TARGETS API
# ============================================

@app.route("/api/scan_targets")
@require_auth
def api_scan_targets():
    rows = query_db("SELECT * FROM scan_targets ORDER BY id")
    return jsonify(_serialize(rows))


@app.route("/api/scan_targets", methods=["POST"])
@require_auth
def api_scan_target_create():
    data = request.get_json()
    execute_db(
        "INSERT INTO scan_targets (site_url, country_code, proxy_url, proxy_type, is_active, notes) "
        "VALUES (%s, %s, %s, %s, %s, %s)",
        (
            data["site_url"], data["country_code"],
            data.get("proxy_url"), data.get("proxy_type", "socks5"),
            data.get("is_active", True), data.get("notes"),
        ),
    )
    return jsonify({"ok": True})


@app.route("/api/scan_targets/<int:target_id>", methods=["PUT"])
@require_auth
def api_scan_target_update(target_id):
    data = request.get_json()
    fields = ["site_url", "country_code", "proxy_url", "proxy_type", "is_active", "notes"]
    sets = []
    params = []
    for f in fields:
        if f in data:
            sets.append(f"{f} = %s")
            params.append(data[f])
    if sets:
        params.append(target_id)
        execute_db(f"UPDATE scan_targets SET {', '.join(sets)} WHERE id = %s", params)
    return jsonify({"ok": True})


@app.route("/api/scan_targets/<int:target_id>", methods=["DELETE"])
@require_auth
def api_scan_target_delete(target_id):
    execute_db("DELETE FROM scan_targets WHERE id = %s", (target_id,))
    return jsonify({"ok": True})


# ============================================
# CONTENT QUEUE API
# ============================================

@app.route("/api/content_queue")
@require_auth
def api_content_queue():
    status = request.args.get("status")
    limit = int(request.args.get("limit", 50))
    where = ""
    params = []
    if status:
        where = "WHERE status = %s"
        params.append(status)
    params.append(limit)
    rows = query_db(
        f"SELECT * FROM content_queue {where} ORDER BY created_at DESC LIMIT %s",
        params,
    )
    return jsonify(_serialize(rows))


# ============================================
# AB TESTS API
# ============================================

@app.route("/api/ab_tests")
@require_auth
def api_ab_tests():
    rows = query_db("SELECT * FROM ab_tests ORDER BY started_at DESC LIMIT 50")
    return jsonify(_serialize(rows))


# ============================================
# WORKFLOW LOCKS API
# ============================================

@app.route("/api/locks")
@require_auth
def api_locks():
    rows = query_db("SELECT * FROM workflow_locks ORDER BY locked_at DESC")
    return jsonify(_serialize(rows))


@app.route("/api/locks/<path:lock_name>", methods=["DELETE"])
@require_auth
def api_lock_delete(lock_name):
    execute_db("DELETE FROM workflow_locks WHERE lock_name = %s", (lock_name,))
    return jsonify({"ok": True})


# ============================================
# STATS CHARTS API
# ============================================

@app.route("/api/charts/spend")
@require_auth
def api_chart_spend():
    days = int(request.args.get("days", 14))
    rows = query_db(
        "SELECT date, SUM(money) as spend, SUM(postbacks_confirmed_money) as revenue, "
        "SUM(profit) as profit FROM ad_stats "
        "WHERE date >= CURRENT_DATE - %s "
        "GROUP BY date ORDER BY date",
        (days,),
    )
    return jsonify(_serialize(rows))


@app.route("/api/charts/bid_changes")
@require_auth
def api_chart_bid_changes():
    days = int(request.args.get("days", 7))
    rows = query_db(
        "SELECT DATE(changed_at) as date, "
        "COUNT(*) as total, "
        "SUM(CASE WHEN new_bid > old_bid THEN 1 ELSE 0 END) as raised, "
        "SUM(CASE WHEN new_bid < old_bid THEN 1 ELSE 0 END) as lowered, "
        "SUM(CASE WHEN rule_applied LIKE '%%STOP%%' THEN 1 ELSE 0 END) as stopped "
        "FROM bid_history WHERE changed_at >= NOW() - make_interval(days => %s) "
        "GROUP BY DATE(changed_at) ORDER BY date",
        (days,),
    )
    return jsonify(_serialize(rows))


@app.route("/api/charts/balance")
@require_auth
def api_chart_balance():
    hours = int(request.args.get("hours", 48))
    rows = query_db(
        "SELECT collected_at, balance, spend_rate_per_hour "
        "FROM balance_history WHERE collected_at >= NOW() - make_interval(hours => %s) "
        "ORDER BY collected_at",
        (hours,),
    )
    return jsonify(_serialize(rows))


# ============================================
# HELPERS
# ============================================

def _serialize(obj):
    if obj is None:
        return None
    if isinstance(obj, list):
        return [_serialize(r) for r in obj]
    if isinstance(obj, dict):
        result = {}
        for k, v in obj.items():
            if isinstance(v, datetime):
                result[k] = v.isoformat()
            elif isinstance(v, timedelta):
                result[k] = str(v)
            elif hasattr(v, "__float__"):
                result[k] = float(v)
            else:
                result[k] = v
        return result
    return obj


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8585, debug=True)
