# 优化待办池（Optimization Backlog）

> 已调研确认、暂缓实施的优化项。实施前先本地验证，攒批再构建（构建频率偏好）。
> 归档时间：2026-08-13（全方位审计后）

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
