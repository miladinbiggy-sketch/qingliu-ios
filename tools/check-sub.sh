#!/data/data/com.termux/files/usr/bin/bash
# 在 Termux 里先验订阅链接，别到 iOS 上才发现拉不到。
# 用法: bash check-sub.sh "https://面板/api/v1/client/subscribe?token=xxx"

set -euo pipefail
URL="${1:?用法: bash check-sub.sh <订阅地址>}"

echo "== 1. 用 clash UA 拉一次 =="
BODY=$(curl -sS -m 20 -A "clash-verge/v1.7.7" "$URL")
echo "字节数: ${#BODY}"

if printf '%s' "$BODY" | head -c 400 | grep -q "proxies:"; then
  echo "格式: Clash YAML"
  printf '%s' "$BODY" | grep -cE '^\s*-?\s*name:' | xargs echo "疑似节点数:"
elif printf '%s' "$BODY" | head -c 200 | base64 -d >/dev/null 2>&1; then
  echo "格式: Base64"
  printf '%s' "$BODY" | base64 -d 2>/dev/null | grep -c "://" | xargs echo "链接条数:"
else
  echo "格式: 未知 —— 前 300 字节如下"
  printf '%s' "$BODY" | head -c 300
fi

echo
echo "== 2. 默认 UA 对照 =="
curl -sS -m 20 -o /dev/null -w "HTTP %{http_code}  下载 %{size_download} 字节\n" "$URL"
