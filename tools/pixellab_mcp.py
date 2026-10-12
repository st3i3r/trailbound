#!/usr/bin/env python3
"""PixelLab MCP client — call MCP tools, poll async jobs, save images.
Stdlib only.

Usage:
  python tools/pixellab_mcp.py <tool_name> '<json args>'   # call a tool
  python tools/pixellab_mcp.py <tool_name> @args.json      # args from file
      [--save DIR [--prefix NAME]]      save every returned image to DIR
      [--poll <get_tool> <id_field>]    submit is async: find the id in the
                                        reply, then poll get_tool {id_field:
                                        id} every 15s until a terminal status
                                        (completed/review/ready; --terminal
                                        overrides)
  python tools/pixellab_mcp.py --get <url> <out_path>      # download a URL
      (tileset image/metadata links need no auth header)

Each call runs initialize -> notifications/initialized -> tools/call (the
endpoint is stateless). Prints the tool's concatenated content[].text and
exits non-zero on a JSON-RPC error, result.isError, or a failed job.
Token: PIXELLAB_TOKEN env var, else parsed from <repo>/.env. Never printed.
"""
import base64, hashlib, io, itertools, json, os, re, sys, time
import urllib.error, urllib.request, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MCP = "https://api.pixellab.ai/mcp"
TERMINAL = ("completed", "review", "ready")
_IDS = itertools.count(1)


def token():
    t = os.environ.get("PIXELLAB_TOKEN")
    if t:
        return t.strip()
    env = os.path.join(ROOT, ".env")
    if os.path.exists(env):
        for line in open(env):
            line = line.strip()
            if line.startswith("PIXELLAB_TOKEN="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("PIXELLAB_TOKEN not set and not found in " + env)


def post(msg, tries=4):
    req = urllib.request.Request(
        MCP, data=json.dumps(msg).encode(),
        headers={"Authorization": "Bearer " + token(),
                 "Content-Type": "application/json",
                 "Accept": "application/json, text/event-stream"})
    for i in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                return resp.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            sys.exit(f"HTTP {e.code}: "
                     f"{e.read()[:500].decode('utf-8', 'replace')}")
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            if i == tries - 1:
                sys.exit(f"transport error after {tries} tries: {e}")
            time.sleep(5 * (i + 1))


def responses(body):
    """Decode a reply body — SSE stream or plain JSON — into messages."""
    body = body.strip()
    if not body:
        return []
    if body[0] in "[{":
        return [json.loads(body)]
    return [json.loads(l[5:].strip())
            for l in body.splitlines() if l.startswith("data:")]


def rpc(method, params=None, rid=None):
    msg = {"jsonrpc": "2.0", "method": method}
    if params is not None:
        msg["params"] = params
    if rid is not None:
        msg["id"] = rid
    msgs = responses(post(msg))
    if rid is None:
        return None
    for m in msgs:
        if m.get("id") == rid:
            return m
    sys.exit(f"no response for id {rid}: {msgs!r:.300}")


def session_init():
    rpc("initialize", {
        "protocolVersion": "2025-03-26",
        "capabilities": {},
        "clientInfo": {"name": "trailbound-tools", "version": "1.0"}},
        rid=next(_IDS))
    rpc("notifications/initialized")


def res_text(res):
    return "".join(c.get("text", "") for c in res.get("content", [])
                   if c.get("type") == "text")


def tool_call(name, args):
    """tools/call -> result dict; exits non-zero on rpc error/isError."""
    r = rpc("tools/call", {"name": name, "arguments": args}, rid=next(_IDS))
    if "error" in r:
        print(json.dumps(r["error"], indent=1), file=sys.stderr)
        sys.exit(1)
    res = r.get("result") or {}
    if res.get("isError"):
        print(res_text(res))
        sys.exit(1)
    return res


def call_tool(name, args):
    """init + tools/call, print text -> result dict."""
    session_init()
    res = tool_call(name, args)
    print(res_text(res))
    return res


def find_id(text, field=None):
    if field:
        m = re.search(re.escape(field) + r"\s*[:=]\s*([0-9a-zA-Z-]{8,})",
                      text)
        if m:
            return m.group(1)
    m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}"
                  r"-[0-9a-f]{12}", text)
    if m:
        return m.group(0)
    m = re.search(r"\bid\s*[:=]\s*(\S+)", text)
    return m.group(1) if m else None


def status_of(text):
    m = re.search(r"status:\s*([a-z_]+)", text)
    return m.group(1) if m else "?"


def wait_for(tool, field, ident, terminal=TERMINAL, interval=15,
             timeout=1500):
    """Poll a get_* tool until a terminal status -> final result dict."""
    t0 = time.time()
    while True:
        res = tool_call(tool, {field: ident})
        text = res_text(res)
        st = status_of(text)
        print(f"  {tool} {str(ident)[:8]}: {st}", flush=True)
        if st in ("failed", "error"):
            print(text)
            sys.exit(1)
        if st in terminal:
            print(text)
            return res
        if time.time() - t0 > timeout:
            sys.exit(f"timeout waiting for {ident} ({tool})")
        time.sleep(interval)


def extract_assets(res):
    """-> [('png', bytes) | ('zip', bytes)] from image blocks plus https
    png/zip URLs mentioned in text blocks."""
    out = []
    for c in res.get("content", []):
        if c.get("type") == "image" and c.get("data"):
            out.append(("png", base64.b64decode(c["data"])))
        elif c.get("type") == "text":
            for u in re.findall(r"https?://\S+", c.get("text", "")):
                u = u.rstrip(").,;>\"'")
                if re.search(r"\.(png|zip|ttf|json)(\?|$)"
                             r"|/(download|image|metadata)(\?|$)", u, re.I):
                    out.append(("url", u))
    return out


def save_assets(res, outdir, prefix, start=0):
    """Save extracted assets as DIR/prefix_<i>.png (zips are unpacked to
    prefix_<i>_<member>). Returns saved paths."""
    os.makedirs(outdir, exist_ok=True)
    saved, i, seen = [], start, set()
    urls_seen = set()
    for kind, payload in extract_assets(res):
        if kind == "url":
            if payload in urls_seen:
                continue
            urls_seen.add(payload)
            try:
                req = urllib.request.Request(
                    payload, headers={"User-Agent": "trailbound-tools"})
                data = urllib.request.urlopen(req, timeout=120).read()
            except Exception as e:
                print("  download failed:", payload[:90], "->", e)
                continue
            if data[:2] == b"PK":
                kind = "zip"
            elif data.lstrip()[:1] in (b"{", b"["):
                kind = "json"
            elif data[:4] in (b"\x00\x01\x00\x00", b"OTTO"):
                kind = "ttf"
            else:
                kind = "png"
            payload = data
            if kind in ("zip", "json", "ttf"):
                h0 = hashlib.md5(payload).hexdigest()
                if h0 in seen:
                    continue
                seen.add(h0)
        if kind in ("json", "ttf"):
            p = os.path.join(outdir, f"{prefix}_{i}.{kind}")
            open(p, "wb").write(payload)
            saved.append(p)
            i += 1
        elif kind == "zip":
            z = zipfile.ZipFile(io.BytesIO(payload))
            for n in z.namelist():
                base = os.path.basename(n)
                if not base or not base.lower().endswith(
                        (".png", ".json")):
                    continue
                p = os.path.join(outdir, f"{prefix}_{i}_{base}")
                open(p, "wb").write(z.read(n))
                saved.append(p)
            i += 1
        else:
            h = hashlib.md5(payload).hexdigest()
            if h in seen:
                continue
            seen.add(h)
            p = os.path.join(outdir, f"{prefix}_{i}.png")
            open(p, "wb").write(payload)
            saved.append(p)
            i += 1
    for p in saved:
        try:
            rp = os.path.relpath(p, ROOT)
        except ValueError:
            rp = p
        print("  saved", rp)
    return saved


def get(url, out_path, tries=4):
    req = urllib.request.Request(url,
                                 headers={"User-Agent": "trailbound-tools"})
    data = None
    for i in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = resp.read()
            break
        except urllib.error.HTTPError as e:
            sys.exit(f"HTTP {e.code}: "
                     f"{e.read()[:500].decode('utf-8', 'replace')}")
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            if i == tries - 1:
                sys.exit(f"transport error after {tries} tries: {e}")
            time.sleep(5 * (i + 1))
    out_path = os.path.abspath(out_path)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(data)
    print(out_path, len(data), "bytes")


USAGE = __doc__

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    av = sys.argv[1:]
    if av and av[0] == "--get":
        if len(av) != 3:
            sys.exit("usage: --get <url> <out_path>")
        get(av[1], av[2])
        sys.exit(0)

    save_dir = prefix = poll_tool = poll_field = None
    terminal = TERMINAL
    pos, i = [], 0
    while i < len(av):
        if av[i] == "--save":
            save_dir = av[i + 1]; i += 2
        elif av[i] == "--prefix":
            prefix = av[i + 1]; i += 2
        elif av[i] == "--poll":
            poll_tool, poll_field = av[i + 1], av[i + 2]; i += 3
        elif av[i] == "--terminal":
            terminal = tuple(av[i + 1].split(",")); i += 2
        else:
            pos.append(av[i]); i += 1
    if not (1 <= len(pos) <= 2):
        sys.exit(USAGE)
    a = pos[1] if len(pos) == 2 else "{}"
    if a.startswith("@"):
        a = open(a[1:], encoding="utf-8").read()

    res = call_tool(pos[0], json.loads(a))
    n0 = 0
    if save_dir:
        n0 = len(save_assets(res, save_dir, prefix or pos[0]))
    if poll_tool and status_of(res_text(res)) not in terminal:
        ident = find_id(res_text(res), poll_field)
        if not ident:
            sys.exit("could not find an id to poll in the response")
        res = wait_for(poll_tool, poll_field, ident, terminal=terminal)
        if save_dir:
            save_assets(res, save_dir, prefix or pos[0], start=n0)
