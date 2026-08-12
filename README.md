# 一加 13 (SM8750) 6.6 内核构建

基于 [cctv18/oppo_oplus_realme_sm8750](https://github.com/cctv18/oppo_oplus_realme_sm8750) 的 CI 脚本深度改进版。终极拼好核缝合型脚本，为了让我的手机变得更好使这一前提下诞生的搞笑奇异编译脚本
感谢cctv18大佬和wild kernels大佬的脚本
我也不知道写了多少调整在cctv18大佬的基础上，反正脚本里面应该能看出来具体的优化步骤，
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

## zram 双重压缩（lz4kd 主算法 + zstd 重压缩）

内核已启用 `ZRAM_MULTI_COMP` + `ZRAM_MEMORY_TRACKING`：
- **主算法 lz4kd**：新写入的页（常用/活跃数据）用 lz4kd 压缩（快）
- **重压缩 zstd**：idle 页（不常用数据）可经 recompression 转 zstd（压缩率高，省内存）

设备端启用（需要 root；Android 15+ 的 mmd 会自动调度，也可手动）：

```sh
# 1. 配置重压缩目标算法（zstd 优先，可加 lz4hc 备用）
echo "algo=zstd priority=1" > /sys/block/zram0/recomp_algorithm
# 2. 触发全部页重压缩（mmd 会自动做，这里用于手动立即执行）
echo all > /sys/block/zram0/recompress
# 3. 查看状态
cat /sys/block/zram0/recomp_algorithm
cat /sys/block/zram0/mm_stat
```

说明：写入新页始终用主算法 lz4kd；recompression 只处理已 idle 的页（不常用的转 zstd 后解压略慢但省内存，常用页保持 lz4kd 快速解压）。
