# 一加 13 (SM8750) 6.6 内核构建

基于 [cctv18/oppo_oplus_realme_sm8750](https://github.com/cctv18/oppo_oplus_realme_sm8750) 的 CI 脚本深度改进版，2026-08 完成**模块化重构**——构建逻辑从单体工作流内嵌 bash 提取为 `scripts/` 独立模块，工作流仅保留编排。

## 仓库结构

```
.github/workflows/6.6.118.yml   工作流编排（inputs 定义 + 步骤调用）
scripts/
  common.sh         公共库（日志/网络回退/补丁拉取）
  init_env.sh       环境依赖 + OEM/vendor 源码 + AOSP merge + 工具链（Clang19 + build-tools 官方源）
  ccache_setup.sh   ccache 配置（40G/依赖模式/日志开关）
  apply_patches.sh  KernelSU/SUSFS/lz4/lz4kd/风驰批/功能开关补丁
  config_inject.sh  defconfig 注入/cmdline/版本固化
  build_kernel.sh   增量钳制/.config 指纹/工具链验证/编译/IKCFG 产物校验
  package.sh        KPM 修补/AnyKernel3 打包/本地保存/清理
other_patch/        本仓库维护的补丁（zram_recomp/damon/adios/apk_sign/69_hide_stuff）
droidspaces_patch/  Droidspaces 容器支持补丁
```

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
- wild kernels [https://github.com/WildKernels/OnePlus_KernelSU_SUSFS]

## zram 双重压缩（lz4 主算法 + zstd 冷数据重压缩）

内核已启用 `ZRAM_MULTI_COMP` + `ZRAM_MEMORY_TRACKING`：
- **主算法 lz4 1.10 全特性**：新写入的页（常用/活跃数据）用 lz4 压缩——NEON 解压（lz4armv8.S）+ `LZ4_FAST_DEC_LOOP` 快循环，解压最快
- **重压缩 zstd**：idle 页（冷数据）经 recompression 转 zstd（压缩率高，省内存）

### 开机自动启用（内核已固化 zstd，无需配置算法）

**内核已在设备创建时默认注册 zstd 为冷数据重压缩算法**（`recomp_algorithm` 只能在 zram 初始化前配置，用户态无法介入——直接写 sysfs 会得到 `Device or resource busy`）。因此**不需要**写 `recomp_algorithm`，只需要触发重压缩：

**方式一：KernelSU 模块**（`/data/adb/modules/<模块名>/service.sh`）或 **Magisk**（`/data/adb/service.d/99zram.sh`，记得 `chmod +x`）：

```sh
#!/system/bin/sh
# zram 冷数据重压缩触发（内核默认算法 zstd，type=idle 只压冷数据）
sleep 10
echo "type=idle" > /sys/block/zram0/recompress 2>/dev/null || true
```

**方式二：临时手动触发**：

```sh
echo "type=idle" > /sys/block/zram0/recompress
```

验证：`cat /sys/block/zram0/recomp_algorithm`（应显示 `#1: algo=zstd`，无需自己写）。

说明：`type=idle` 只重压缩冷数据页（避免 `echo all` 把活跃页也压到 zstd 导致解压变慢）；内核已每 30 分钟自动执行相同操作，脚本仅为手动立即触发。

说明：
- 写入新页始终用主算法 lz4（常用数据快速解压）；`recompress` 只处理已 idle 的页（冷数据转 zstd 省内存）
- `mm_stat` 可查看压缩效果（`cat /sys/block/zram0/mm_stat`）
- Android 15+ 的 mmd 会自动调度 recompression，脚本为兜底/手动触发
