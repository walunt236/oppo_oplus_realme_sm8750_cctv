# 优化待办池（Optimization Backlog）

> 已调研确认、暂缓实施的优化项。实施前先本地验证，攒批再构建（构建频率偏好）。
> 归档时间：2026-08-13（全方位审计后）；2026-08-17 增补方向二规划

## 方向二：Anti-Fuse 防熔断（⚠ 已验证不可行于当前构建链，2026-08-17）

### ⚠ 验证结论（2026-08-17 实测，规划修正）
| 环节 | 验证结果 |
|---|---|
| module-intercept patch（WildKernels android15-6.6 版，brokestar233 出品） | ✅ 机制完整：`.ko`→字节数组内嵌，`load_module()` 签名检查前 1:1 替换同名模块 |
| 预编译 `qcom-scm_sm8750_A16_android15-6.6.89.ko`（148KB，aarch64） | ❌ **vermagic 不匹配**：`6.6.89-android15-8-o-g730abe20ed39-4k` vs 我们内核 `6.6.118-oneplus13-4k-aosp16_142`——Android `check_vermagic` 严格字符串比较（vermagic.c 无放宽），intercept 替换后仍会在 check_modinfo 失败（-ENOEXEC） |
| 重新编译 .ko 适配我们内核 | ❌ qcom-scm 源码不在 vendor_modules 仓库（该仓只有 KGSL 等部分驱动）；SCM 在设备上是 vendor 模块（我们内核 CONFIG_QCOM_SCM 无、vmlinux 0 符号） |
| 内核侧 vendor hook 拦截（`android_vh_fuse_request_end`） | ❌ **该 hook 是 FUSE 文件系统（storage）hook**（签名 `struct task_struct *self`，与 `queue_request_and_unlock` 同族），与 Qualcomm 硬件 eFuse/ARB 烧写**无关**——无现成内核侧拦截点 |
| 可行前提 | **仅官方 android15-6.6 基线内核**（vermagic 形如 `6.6.x-android15-8-o-...`，uparrows 的 fastbuild_6.6.x workflow 即此路线）——与我们的 OEM 内核路线不兼容 |

### 结论
**Anti-fuse 在我们构建链上不可行**（除非：① 搞到 qcom-scm 源码用我们的环境重编；② wrap `__arm_smccc_smc` 逆向 SCM 功能号——都属高成本高风险）。**维持关闭状态，不再投入**。若未来想走此方向，正确路线是"官方基线内核 + anti-fuse"（那是另一个内核路线，非本仓库 OEM 路线）。

### 原规划背景（存档）
- ARB（Anti-RollBack）：Qualcomm 熔断机制，OOS 16.0.7/16.0.8 引入 `update_arb` sysfs 继续烧 fuse
- 参考实现：`github.com/uparrows/oppo_oplus_realme_sm8750`（cctv18 fork）；WildKernels `oneplus/module_overlay/`
- 刷写流程：更新后刷另一槽 + `abl_a`/`xbl_a`/`xbl_config_a`/`xbl_ramdump_a` + vbmeta disabled
- 风险：SCM 拦截影响 TZ/QHEE；fuse 单向不可逆；abl/xbl 刷错硬砖

### 关联
- [[kernel-vendor-lockdown]]（KMI 冻结/闭源驱动约束背景）
- 设备身份与 ARB：见 kernel-build-verify skill 的设备信息章节

---

## 待实施

### B1. zram 三件套（官方零改动，纯增量）⭐
- 载体：`other_patch/zram_recomp_default.patch` 扩展
- 内容：
  1. **huge 页统计**：自动重压缩循环中统计 `ZRAM_HUGE` 页数量（观测 incompressible 页的内存浪费，mmd 的 idle_huge 思路）
  2. **zstd level 3 → 9**：次级算法用更高压缩级别（冷数据不常读，解码慢无感，压缩率 +5~10%）
  3. **周期任务追加 `zram_compact()`**：30min 周期内顺带回收 zsmalloc 碎片
- 收益：中 | 风险：低 | 工作量：1 个补丁文件

### B2. 关闭运行时调试配置（官方 GKI 基线默认带）⭐
- 载体：`.github/workflows/6.6.118.yml` 配置注入
- 内容：
  - `CONFIG_PM_DEBUG=n` / `CONFIG_PM_ADVANCED_DEBUG=n` / `CONFIG_PM_SLEEP_DEBUG=n`（suspend/resume 路径调试开销，无 vendor 符号依赖）
  - `CONFIG_PAGE_OWNER=n` / `CONFIG_SLUB_DEBUG=n` / `CONFIG_CMA_DEBUGFS=n`（静态开销）
- **⚠ 不可动**：`CONFIG_KASAN` / `CONFIG_UBSAN`（vendor 模块编译期插桩依赖导出符号，配置级关闭将 bootloop——见工作流 OEMDEPENDS 块）
- 收益：小 | 风险：低 | 工作量：6 行注入

### B3. cmdline `kasan=off`（可选，待实机确认）
- 机制：保留 KASAN 配置与符号（vendor 兼容），仅运行时关闭检查，省 MTE tag ~3% 内存 + CPU 开销
- 前置确认（设备端）：
  - `cat /proc/cmdline` —— 官方是否已带 `kasan=off`
  - `dmesg | grep -i kasan` —— KASAN 是否真在运行
- 收益：大 | 风险：中（需实机验证） | 工作量：1 行 cmdline 注入

## 已完成（参考，勿重复）

- zram 双重压缩 + 30min 自动重压缩（lz4 主 / zstd 冷数据）— 实机验证 mem_used -380MB
- LZ4 1.10 全特性（NEON / FAST_DEC_LOOP / -O3 / accel=1）
- HMBIRD 调度类（官方半成品 + 风驰补丁；build_policy.c include 编译，vmlinux 注册验证）
- wild 内存补丁 5/6 生效；clear_page 16B 对齐补丁上游 6.6.118 已合并 → 2026-08-13 移除（死代码）
- 设备端运行时调优全套（vm / 调度 / MGLRU / DAMON / 网络 / f2fs / IRQ affinity）— `D:\service (2).sh`
- SLIM_SCHED / SCHED_CLASS_EXT 为官方死配置（Kconfig 已删除，OPlus 已用 HMBIRD 取代），勿恢复
