# 热食蒸汽迁移进度（2026-10-16）

状态：模型对照 PASS；原生渲染已接入，GPU 颜色/透明/深度对照 UNDETERMINED。不构成全游戏 95% 验收。

## 原版规则与实现

唯一基准仍为冻结 h5-source chapter1 6a316e84907d8bc94ab59f20796685172b3535b5。第一章未提交调色的 SHA256 复核仍为 1dae5f70540d5606ba113498d202bf45175721f817c8ef983669adf0ef8101a9。未修改冻结源码。

- HotFoodSteam 模型保留 buildHotFood 的 rng(77) 随机流，包括蒸汽初始化前烤肠、关东煮、炸鸡几何消耗的 140 次调用。90 个粒子初始化后累计 680 次。
- 关东煮/包子柜/烤肠的发射概率为 0.5/0.35/0.15；生命周期、上升、正弦漂移及颜色衰减逐项来自原版。内部积分使用双精度，提交位置/颜色保留 Float32Array 取整行为。
- 冻结 store.js 的 steam 参数不乘停电或焦虑系数；停电后热食仍在冒气。折叠时粒子中心随 furniture 变换，但屏幕点大小不随父节点缩放。
- HotFoodSteamRenderer 在 UrhoX 中生成面向相机的四边形，使用原 paintDot 的线性派生纹理、加法混合、不写深度。点大小按 Three 的 h/2 距离衰减还原，包含最小 1 像素限制。
- 粒子颜色走未使用的 Float32 normal 顶点流传入自定义 varying，避免低亮度蒸汽在打包顶点色中被量化到 8 位。这个 shader 通路仍需 GPU 实测确认。
- StoreRenderer 更新、参考帧重置与资源释放已接入；其他章节/回响不会额外生成这组粒子。

## 已完成证据

- `python3 tests/test_hot_food_steam.py`：PASS；1,200 帧 × 90 粒子，1,296,000 项标量检查；同一实际冻结 buildHotFood 构造/更新与 Lua 比较，包含重复重生、dt=0、0/.64/1/1.7 蒸汽强度与 120 个暂停帧。最终 RNG 调用 9,960 次。
- 4 个新增/修改 Lua 文件语法编译通过，git diff --check 通过。
- 全量 LSP 扫描仍是 27 条原有 ERROR，无蒸汽新增 ERROR；原有错误不属于本项已修复范围。日志在 validation/steam/lsp/。
- 已运行独立 Chrome 的实际冻结 buildHotFood 渲染，2448×1376 共 7 个源版样本：初始、2 秒、amount=0、移动相机首帧/稳定帧、父节点折叠、深度无写入。保存于 validation/steam/source/，不是 native 对照结果。

## 本地预览与待办

代码批次后检查 live status 并刷新至 reload 48 / PID 94846；捕获了正常标题与进入序章的画面。之后 CLI 返回 state=stopped / process_alive=false，原生蒸汽测试入口尚未启动。已遵守 AGENTS 不自动复活停止窗口的规则，发出一次重新打开确认，且将 .project/project.json 恢复 main.lua。

最后官方 check 为 FAIL，含已有 Cube/Day/DaySpecularHDR_QualityLow.dds 缺失；停止后的历史证据不能证明当前源码运行正常。

下一步在获得重新打开授权后：

1. 使用 preview/steam-check.lua 与 tests/capture-native-steam.py 获取 7 个原生样本。
2. 同尺寸对照源版颜色/位置/覆盖，确认零深度写入、折叠大小、相机首帧同步；不得用共同黑色背景降低误差。
3. 恢复 main.lua 并检查实际热食柜、停电、折叠的后处理合成。

捕获脚本：tests/capture-steam-reference.mjs 可接受显式 width height（独立源版样本）；未指定尺寸则读取原生 receipt。本次没有创建虚假的 native receipt，也没有声明蒸汽视觉通过。
