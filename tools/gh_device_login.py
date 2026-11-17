#!/usr/bin/env python3
"""GitHub 设备授权流程（走 gh 的公开 client_id），授权后把 token 存到 ~/.dsh/github_token。"""
import json, os, sys, time, urllib.parse, urllib.request

CLIENT_ID = "178c6fc778ccc68e1d6a"  # GitHub CLI 的公开 OAuth client id
SCOPE = "repo workflow"
TOKEN_PATH = os.path.expanduser("~/.dsh/github_token")


def post(url, data):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, headers={
        "Accept": "application/json",
        "User-Agent": "dsh-go/1.0",
    })
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read().decode())


STATE_PATH = os.path.expanduser("~/.dsh/gh_device_state.json")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "--start"
    if mode == "--poll":
        d = json.load(open(STATE_PATH))
    else:
        d = post("https://github.com/login/device/code",
                 {"client_id": CLIENT_ID, "scope": SCOPE})
        os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
        json.dump(d, open(STATE_PATH, "w"))
    if "device_code" not in d:
        print("申请失败:", d); sys.exit(1)

    code = d["user_code"]
    uri = d.get("verification_uri", "https://github.com/login/device")
    interval = int(d.get("interval", 5))
    expires = int(d.get("expires_in", 900))

    print(f"USER_CODE={code}")
    print(f"URL={uri}")
    print(f"EXPIRES_IN={expires}", flush=True)

    deadline = time.time() + expires
    while time.time() < deadline:
        time.sleep(interval)
        r = post("https://github.com/login/oauth/access_token", {
            "client_id": CLIENT_ID,
            "device_code": d["device_code"],
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        })
        err = r.get("error")
        if err == "authorization_pending":
            continue
        if err == "slow_down":
            interval += 5
            continue
        if err in ("expired_token", "access_denied"):
            print("AUTH_FAILED:", err); sys.exit(2)
        token = r.get("access_token")
        if token:
            os.makedirs(os.path.dirname(TOKEN_PATH), exist_ok=True)
            with open(TOKEN_PATH, "w") as f:
                f.write(token)
            os.chmod(TOKEN_PATH, 0o600)
            # 顺便查一下身份
            try:
                req = urllib.request.Request("https://api.github.com/user", headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/vnd.github+json",
                    "User-Agent": "dsh-go/1.0",
                })
                with urllib.request.urlopen(req, timeout=20) as resp:
                    me = json.loads(resp.read().decode())
                print(f"AUTH_OK login={me.get('login')} plan={((me.get('plan') or {}).get('name'))}")
            except Exception as e:
                print("AUTH_OK (用户信息读取失败)", e)
            sys.exit(0)
    print("AUTH_FAILED: timeout"); sys.exit(3)


if __name__ == "__main__":
    main()
