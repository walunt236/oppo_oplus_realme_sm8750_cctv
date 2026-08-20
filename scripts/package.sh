#!/bin/bash
# package.sh — KPM 修补/AnyKernel3 打包/本地保存/清理
set -e
source "$(dirname "$0")/common.sh"

# ===== KPM 修补 =====
if [[ "$KPM_ENABLE" == 'builtin' ]] && ( [[ "$KSU_TYPE" == "sukisu" ]] || [[ "$KSU_TYPE" == "resukisu" ]] ); then
  info "应用 KPM 并修补内核..."
  cd kernel_workspace/common/out/arch/arm64/boot
  curl -fSL --retry 3 --retry-delay 5 --retry-all-errors -o patch_linux "https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/latest/download/patch_linux" || {
    error "KPM patch_linux 下载失败"
    exit 1
  }
  chmod +x patch_linux
  ./patch_linux
  rm -f Image
  mv oImage Image
fi
if [[ "$KPM_ENABLE" == 'kpn' ]]; then
  info "应用 KP-N 并修补内核..."
  cd kernel_workspace/common/out/arch/arm64/boot
  curl -fSL --retry 3 --retry-delay 5 --retry-all-errors --connect-timeout 10 --max-time 30 -o kptools-linux "https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kptools-linux" || {
    warn "KPN kptools download timed out, skipping"
    exit 0
  }
  curl -fSL --retry 3 --retry-delay 5 --retry-all-errors --connect-timeout 10 --max-time 30 -o kpimg-linux "https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kpimg-linux" || {
    warn "KPN kpimg download timed out, skipping"
    exit 0
  }
  chmod +x ./kptools-linux
  ./kptools-linux -p -i ./Image -k ./kpimg-linux -o ./oImage
  rm -f Image
  mv oImage Image
fi

# ===== AnyKernel3 打包 =====
cd kernel_workspace
CLONE_OK=0
if [ -d AnyKernel3/.git ]; then
  info "AnyKernel3 仓库已存在，增量同步..."
  if git -C AnyKernel3 fetch --depth=1 origin && git -C AnyKernel3 reset --hard FETCH_HEAD; then
    CLONE_OK=1
  else
    warn "AnyKernel3 增量拉取失败，使用本地已有版本"
    CLONE_OK=1
  fi
fi
if [[ $CLONE_OK -ne 1 ]]; then
  rm -rf AnyKernel3
  for i in 1 2 3 4 5 6 7 8; do
    if git clone https://github.com/walunt236/AnyKernel3 --depth=1 AnyKernel3; then
      CLONE_OK=1
      break
    fi
    warn "AnyKernel3 克隆失败(第${i}次)，5 秒后重试..."
    sleep 5
  done
fi
if [[ $CLONE_OK -ne 1 ]]; then
  error "AnyKernel3 克隆失败，终止打包"
  exit 1
fi
# zip 用 ./* 通配符，.git 不打包但保留供下次增量拉取
cd AnyKernel3
# 一加13 适配 overlay（官方模板 + 自控适配，官方更新直接合并）
cp -r "$GITHUB_WORKSPACE/ak3_overlay/"* . 2>/dev/null || true
cp ../common/out/arch/arm64/boot/Image ./Image
if [[ ! -f ./Image ]]; then
  error "未找到内核镜像文件"
  exit 1
fi

case "$KSU_TYPE" in
  sukisu)   KSU_TYPENAME="SukiSU" ;;
  resukisu) KSU_TYPENAME="ReSukiSU" ;;
  ksunext)  KSU_TYPENAME="KSUNext" ;;
  ksu)      KSU_TYPENAME="KSU" ;;
  *)        KSU_TYPENAME="none" ;;
esac

if [[ "$KPM_ENABLE" == 'kpn' ]]; then
  curl -fSL --retry 3 --retry-delay 5 --retry-all-errors --connect-timeout 10 --max-time 30 -o kpn.zip "https://github.com/cctv18/KPatch-Next/releases/latest/download/kpn.zip" || warn "kpn.zip 下载失败，跳过 KPN 模块"
fi

BUILD_DATE="$(TZ=Asia/Shanghai date +%Y%m%d)"
AK3_NAME="AnyKernel3-${KSU_TYPENAME}-${KSUVER}-${KERNEL_VERSION_FULL}-${KERNEL_SUFFIX}-${BUILD_DATE}.zip"
FULL_VERSION="${KERNEL_VERSION_FULL}-${KERNEL_SUFFIX}"
TIME_NOW="$(TZ='Asia/Shanghai' date +'%Y-%m-%d %H:%M:%S')"
{
  echo "Author: $GITHUB_ACTOR"
  echo "Repo: $GITHUB_REPOSITORY"
  echo "Branch: $GITHUB_REF_NAME"
  echo "Run ID: $GITHUB_RUN_ID"
  echo "Commit: $GITHUB_SHA"
  echo "Time: $TIME_NOW"
  echo "Kernel Ver: $FULL_VERSION"
  echo "KSU Branch: ${KSU_TYPENAME}"
  echo "KSU Ver: ${KSUVER}"
  echo "susfs: $SUSFS_ENABLE"
  echo "KPM: $KPM_ENABLE"
  echo "LZ4: on"
  echo "LZ4KD: $LZ4KD_ENABLE"
  echo "IPset: on"
  echo "BBRv3: on"
  echo "Droidspaces: $DROIDSPACES_ENABLE"
  echo "ADIOS: on"
  echo "Re-Kernel: $REKERNEL_ENABLE"
  echo "BBG: $BASEBAND_GUARD"
  echo "RCU_NOCB: $RCU_NOCB_ENABLE"
} > ./ak3.log

zip -r ../$AK3_NAME ./*
echo "ak3name=$AK3_NAME" >> "$GITHUB_OUTPUT"

if [[ "$RUNNER_TYPE" == "self-hosted" ]]; then
  CUSTOM_LOCAL_PATH="/mnt/d/AK3_DOC"

  if [ -n "$CUSTOM_LOCAL_PATH" ]; then
    TARGET_DIR="$CUSTOM_LOCAL_PATH"
  else
    WIN_DESKTOP_RAW=$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('Desktop')" 2>/dev/null | tr -d '\r')
    TARGET_DIR=$(wslpath "$WIN_DESKTOP_RAW" 2>/dev/null)
  fi

  if [ -n "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    cp "../$AK3_NAME" "$TARGET_DIR/"
    info "已成功保存至本地路径: $TARGET_DIR/$AK3_NAME"
  else
    warn "未找到有效的本地输出路径，跳过本地复制"
  fi
fi

# ===== 本地工作区清理 =====
info "清理编译产出和临时文件..."
# 保留 common/out 供增量编译复用（make 依赖追踪自动处理源码/配置变化），仅清理 vendor 输出
rm -rf kernel_workspace/vendor_modules/out
rm -f /tmp/*.patch
ccache -c
info "ccache 已裁剪至上限"
for repo in "$HOME/.cache_patches/"*; do
  [ -d "$repo/.git" ] && git -C "$repo" gc --auto 2>/dev/null || true
done
# 记录本次成功构建的源码指纹+配置哈希（v2 格式 PATCH_HASH|CFG_HASH；失败则不写，下次自动全量）
if [[ -n "${PATCH_HASH:-}" ]] && [[ -n "${CFG_HASH:-}" ]]; then
  mkdir -p "$HOME/.cache_patches"
  printf '%s|%s' "$PATCH_HASH" "$CFG_HASH" > "$HOME/.cache_patches/build_state"
  info "增量指纹+配置哈希已记录，下次相同状态将增量编译"
fi
info "磁盘清理完成"
