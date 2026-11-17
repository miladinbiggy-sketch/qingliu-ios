#!/usr/bin/env python3
"""建仓 → 推送 → 等 Actions → 下载未签名 IPA。token 读 ~/.dsh/github_token。"""
import json, os, subprocess, sys, time, urllib.error, urllib.request

TOKEN = open(os.path.expanduser("~/.dsh/github_token")).read().strip()
REPO = "qingliu-ios"
OUT_DIR = "/sdcard/Download/DSH-Go"
H = {"Authorization": f"Bearer {TOKEN}", "Accept": "application/vnd.github+json",
     "User-Agent": "dsh-go/1.0", "X-GitHub-Api-Version": "2022-11-28"}


def api(method, path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request("https://api.github.com" + path, data=data,
                                 headers=H, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        return {"_error": e.code, "_body": e.read().decode()[:400]}


def sh(*args, **kw):
    print("$", " ".join(args))
    check = kw.pop("check", True)
    r = subprocess.run(args, check=False, capture_output=True, text=True, **kw)
    if check and r.returncode != 0:
        raise RuntimeError(f"{' '.join(args)}\n{r.stderr[-400:]}")
    return r.stdout


def main():
    me = api("GET", "/user")
    if "_error" in me:
        print("token 无效:", me); sys.exit(1)
    owner = me["login"]
    print(f"登录身份: {owner}")

    # 1. 建仓库（public 才有免费 macOS runner 分钟数）
    r = api("POST", "/user/repos", {"name": REPO, "private": False,
                                    "description": "清流 iOS 客户端 · 未签名 IPA 流水线",
                                    "has_issues": False, "has_wiki": False})
    if "_error" in r and r["_error"] != 422:
        print("建仓失败:", r); sys.exit(2)
    print("仓库:", f"https://github.com/{owner}/{REPO}")

    # 2. 推送（token 只在这次命令里出现，不写进 .git/config）
    url = f"https://x-access-token:{TOKEN}@github.com/{owner}/{REPO}.git"
    sh("git", "remote", "remove", "origin", check=False)
    sh("git", "remote", "add", "origin", url)
    sh("git", "push", "-u", "origin", "HEAD:main", "--force")
    sh("git", "remote", "set-url", "origin", f"https://github.com/{owner}/{REPO}.git")

    # 3. 等 workflow
    print("等 Actions 跑…")
    run_id = None
    for _ in range(60):
        time.sleep(10)
        runs = api("GET", f"/repos/{owner}/{REPO}/actions/runs?per_page=5")
        items = runs.get("workflow_runs", [])
        if items:
            run = items[0]
            print(f"  [{run['status']}] {run['name']} #{run['run_number']}")
            if run["status"] == "completed":
                run_id = run["id"]
                print("  结论:", run["conclusion"])
                break

    if not run_id:
        print("超时没等到结果"); sys.exit(3)

    # 4. 下载 artifact
    arts = api("GET", f"/repos/{owner}/{REPO}/actions/runs/{run_id}/artifacts")
    for a in arts.get("artifacts", []):
        if not a["name"].startswith("QingliuVPN"):
            continue
        req = urllib.request.Request(a["archive_download_url"], headers=H)
        os.makedirs(OUT_DIR, exist_ok=True)
        dst = os.path.join(OUT_DIR, a["name"] + ".zip")
        with urllib.request.urlopen(req, timeout=180) as r, open(dst, "wb") as f:
            f.write(r.read())
        print("已下载:", dst, os.path.getsize(dst), "字节")
    print(f"全部产物: https://github.com/{owner}/{REPO}/actions/runs/{run_id}")


if __name__ == "__main__":
    main()
