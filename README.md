# 一加 13 (SM8750) 6.6 内核自动构建

基于 [cctv18/oppo_oplus_realme_sm8750](https://github.com/cctv18/oppo_oplus_realme_sm8750) 的 CI 脚本深度改进版。

---

## 🚀 与原版的核心差异

| | 原版 | 本版 |
|------|------|------|
| 内核版本 | 固定 OEM 6.6.89 | **动态拉取上游 ACK 最新 6.6 tag 并合并** |
| 上游安全补丁 | 无 | ✅ 每次构建自动合入最新 CVE 修复 |
| ZRAM 压缩 | 默认 lzo-rle | **默认 LZ4，ARM64 NEON 汇编加速** |
| 内存回收 | 传统 LRU | **MGLRU 多代 LRU** |
| 编译验证 | 无 | LZ4 NEON 符号检查 / IP6_NF_NAT 诊断 |
| 构建安全 | 无并发控制 | concurrency 防重复 + 120min 超时 |

---

## 已启用优化

### 编译层（内核 config）
- **ZRAM 默认 LZ4** — 开机即用 NEON 加速解压，延迟 -40%
- **MGLRU** — 多任务场景 OOM 率更低
- **RCU_NOCB_CPU** — 减少软中断抢占 UI 线程
- **TCP 缓冲区 8MB** — 蜂窝网络下载更稳定
- **容器基础 namespace** — Termux/proot 性能提升
- **ADIOS IO 调度器** — 降低 IO 延迟
- **BBR / Brutal / Westwood 等 8 种 TCP 拥塞算法**
- **ipset 全类型 + iptables 完整栈** — TProxy 透明代理支持
- **WireGuard / KVM** — 编译进内核
- **可选关闭 32 位兼容层** — 纯 64 位内核

### 构建层（CI 脚本）
- **上游 ACK 自动合并** — `git fetch` 最新 `android15-6.6.xxx` tag → merge 到 OEM
- **可选跳过上游合并** — 出问题时一键回退 OEM 纯净 89
- **LZ4/ZSTD patch 结果可视化** — 构建日志明确显示是否生效
- **ccache 二次编译 2-10 分钟** — 首次约 40-60 分
- **精简 Release Notes** — 功能表格一目了然

---

## 可用功能选项

| 选项 | 说明 |
|------|------|
| `ksu_type` | ReSukiSU / SukiSU Ultra / KernelSU Next / KSU / 无 |
| `susfs_enable` | 隐藏 root 挂载 |
| `kpm_enable` | 内核模块修补 (builtin / kpn) |
| `lz4_enable` | LZ4 1.10.0 + ZSTD 1.5.7 + ARM64 NEON ASM |
| `lz4kd_enable` | LZ4 字典压缩 (zram 更高压缩率) |
| `bbr_enable` | BBR + Brutal 等拥塞算法 |
| `droidspaces_enable` | LXC 容器 + NTSync |
| `better_net` | ipset 全类型 + iptables 增强 |
| `adios_enable` | ADIOS IO 调度器 |
| `rekernel_enable` | Freezer/NoActive 应用冻结 |
| `baseband_guard` | 内核级基带防格机 |
| `compat_disable` | 关闭 32 位兼容层 (纯 64 位) |
| `upstream_merge` | 合并 ACK 最新 6.6 补丁 |

默认全部关闭，按需勾选。

---

## 使用方法

1. Fork 本仓库 + Fork [内核源码仓库](https://github.com/cctv18/android_kernel_common_oneplus_sm8750)
2. Actions → 选择工作流 → Run workflow
3. 从 Release 下载 AnyKernel3 zip
4. **刷入前用 KernelFlasher 备份 boot 分区**
5. 用 HorizonKernelFlasher 或 TWRP 刷入

---

## 鸣谢

- 原始脚本：[cctv18/oppo_oplus_realme_sm8750](https://github.com/cctv18/oppo_oplus_realme_sm8750)
- ReSukiSU：[ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)
- KernelSU：[tiann/KernelSU](https://github.com/tiann/KernelSU)
- KernelSU Next：[pershoot/KernelSU-Next](https://github.com/pershoot/KernelSU-Next)
- susfs4ksu：[ShirkNeko/susfs4ksu](https://github.com/ShirkNeko/susfs4ksu)
- SukiSU 补丁：[SukiSU-Ultra/SukiSU_patch](https://github.com/SukiSU-Ultra/SukiSU_patch)
- 基带保护：[vc-teahouse/Baseband-guard](https://github.com/vc-teahouse/Baseband-guard)
- LZ4 NEON ASM：[ferstar](https://github.com/ferstar) / [Xiaomichael](https://github.com/Xiaomichael) / [cctv18](https://github.com/cctv18)
- ADIOS：[firelzrd/adios](https://github.com/firelzrd/adios)
