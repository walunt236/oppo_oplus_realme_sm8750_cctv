#!/bin/bash
# ============================================================
# common.sh — 构建链公共库（日志/网络/补丁拉取）
# 由 scripts/ 下各模块脚本 source 使用；环境变量由工作流传入
# ============================================================
set -e

LOG_FILE="${LOG_FILE:-$GITHUB_WORKSPACE/build_summary.log}"

info() { echo "[INFO] $*" | tee -a "$LOG_FILE"; }
warn() { echo "[WARN] $*" | tee -a "$LOG_FILE"; }
error() { echo "[ERROR] $*" | tee -a "$LOG_FILE"; }

# 直连优先、失败立即走代理的 git 包装（AOSP googlesource 直连被墙，Clash 混合端口回退）
glr() {
  git -c http.version=HTTP/1.1 "$@" 2>/dev/null ||
    git -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 -c http.version=HTTP/1.1 "$@" 2>/dev/null
}

# 网络代理自动探测：本地代理存在时写入 GITHUB_ENV（规避 github.com TLS 抖动）
detect_proxy() {
  if curl -s -o /dev/null --connect-timeout 2 --max-time 3 --proxy http://127.0.0.1:7897 https://api.github.com 2>/dev/null; then
    echo "http_proxy=http://127.0.0.1:7897" >> "$GITHUB_ENV"
    echo "https_proxy=http://127.0.0.1:7897" >> "$GITHUB_ENV"
    info "检测到本地代理 127.0.0.1:7897，网络操作走代理"
  else
    info "未检测到代理，纯直连模式（api/codeload/SSH443 直连可用，AOSP 走 glr 回退）"
  fi
}

# 从本仓库拉取文件（api.github.com contents，纯直连通道，base64 解码）
fetch_repo_file() {
  local path="$1" out="$2"
  curl -fsSL --retry 3 --retry-delay 5 -H "Authorization: token ${GH_TOKEN:-}" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/$path?ref=$GITHUB_REF_NAME" |
    python3 -c "import sys,json,base64;open('$out','wb').write(base64.b64decode(json.load(sys.stdin)['content']))"
}

# 缓存化克隆/增量更新（补丁仓统一模式：本地已有则增量，否则全量克隆）
ensure_patch_repo() {
  local url="$1" dir="$2" branch="${3:-main}"
  mkdir -p "$HOME/.cache_patches"
  if [ -d "$dir/.git" ]; then
    info "[秒过] 本地补丁仓 $dir 增量同步..."
    git -C "$dir" fetch --depth=1 origin "$branch" || true
    git -C "$dir" reset --hard FETCH_HEAD || true
  else
    info "首次克隆 $url ..."
    git clone --depth=1 "$url" "$dir" -b "$branch"
  fi
}
