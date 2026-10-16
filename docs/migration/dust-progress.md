# 世界微尘与近景合成（2026-10-16）

本项已接入原生渲染，仍不是整款游戏的视觉验收。正式入口保持 `main.lua`，UI 继续使用 NVG；独立检查仅位于 `preview/dust-check.lua`。

## 冻结来源与范围

使用冻结 `world.js buildDust`、`art.js rng/paintDot`、`main.js` 相机跟随和旋转，以及 `post.js` 合成顺序。未修改冻结源码或第一章调色。调色 SHA-256 仍为 `1dae5f70540d5606ba113498d202bf45175721f817c8ef983669adf0ef8101a9`。

当前序章、回响、第一章的 focus proxy 均无旧版 near Things，近景 DOF 的 searchR 为 0。没有把旧版可吸附近景物件的模糊效果带入新版。

- 主场景：260 粒、范围 44×12×30、size .09、源坐标 z=-6，随游戏 dt 旋转 .01 rad/s，不写深度，叠加混合；参与主场景描边和景深。
- 近景：46 粒、范围 6×4×4、size .05，镜头局部 (0,-2,-6.5)，alphaTest .35，写深度；独立颜色目标，在主场景景深/去色后，bloom/磨砂/最终调色前合成。
- Three 的 `opaque_fragment` 会把近景存活像素 alpha 设为 1。实测参考 alpha 只有 0/255，不能把 PNG 的连续 alpha 当成最后的近景覆盖率。
- Native quad 直径使用 `size*tan(fov/2)`，保留 Three Points 的 `size * physicalHeight/2 / depth` 像素尺寸及 1 像素下限。
- 主微尘旋转在场景替换之间保留；第一章暂停/失焦时不再推进后处理时间。

## 色彩与运行端差异

源 `paintDot` 已导出 PNG 与独立 Chrome 再生成图逐像素相同。Runtime 的缩小贴图生成路径和 WebGL sRGB 贴图路径有可见亮度差异。新增 `dust-linear.png` 作为运行端衍生资源：RGB 按 sRGB 解码一次、保留 alpha，用线性纹理产生 mip；原 PNG 和冻结源码保持不变。准备脚本：`tests/prepare-dust-texture.py`。

固定颜色 .4 / alpha .5 的叠加材质检查得到 sRGB 170，生成 pass 的 blend=1（BLEND_ADD），确认是 ONE/ONE；所以主场景 shader 乘一次纹理 alpha 以匹配 Three 的 SRC_ALPHA/ONE。

第一次尝试使用文档描述的 `alpha_to_coverage` 被此 Runtime 的 Surface Shader v1 拒绝。已移除该模式。中间连续 alpha 实验与校准图分别保留在 `validation/dust/native-fractional/`、`native-binary/`、`native-calibration/`，不是通过证据。

## 实测结果

最终独立 native fixture：session `0e8a692e-0aa1-469c-b1ee-2135b07d6cc6`，reload 36，PID 35962，1920×1080。原图在 `validation/dust/native/` 与 `source/`，逐像素放大图 `particle-crops.png` 已人工读取。截图带 ICC 时先转成 sRGB，尺寸不做重采样；报告不使用黑色背景拉高平均分。

| 对照 | 有效像素覆盖 IoU | 有效区域 RGB 绝对误差（0–255） | 源/原生可见粒子组数 |
|---|---:|---:|---:|
| 近景覆盖率 | .99310 | 1.75862 | 26 / 26 |
| 近景颜色 | .99310 | 2.18621 | 26 / 26 |
| 主场景固定机位 | .91160 | 11.67956 | 35 / 35 |
| 主场景移动后机位 | .96104 | 5.73016 | 39 / 39 |

仍有主场景亚像素点边缘差异，最大最近粒子中心距离 .5 像素。不能把近景结果、全黑背景或各场景平均值当作游戏达到 95% 的证明。

镜头跳转后首帧与 24 帧稳定结果：**0 个不同像素**。该检查只证明本次微尘链路，不代表完整输入延迟或全游戏动态视觉验收。

## 自动检查

- `test_world_dust.py`：1142 检查 PASS，包括直接执行冻结 JS `buildDust/rng` 对比 918 个 Float32 坐标值。
- `test_scene_post.py`：261 检查 PASS，5 种尺寸，188 个 surface wrapper 在其父纹理释放前被回收；覆盖近景目标绑定、刷新和尺寸变化。
- `test_scene_style.py`：5029 检查 PASS，原始 4 Hz 描边与章节纸纹参数保持。
- `test_scene_bridge.py`：8361 帧 PASS。
- 完整 LSP 扫描尚有 28 项诊断，见 `validation/dust/lsp/lua_errors.log`；新增 WorldDust/DustPattern/dust-check 文件未在剩余诊断中。不能宣称整个项目 LSP 通过。
- 官方 runtime check 仍有已知 `Cube/Day/DaySpecularHDR_QualityLow.dds` 缺失。最终正式入口的结果另存 `validation/dust/production-check.json`。

正式入口已恢复并实测：reload 37 / PID 38940，1920×1080，从标题“开始游戏”进入便利店；原生截图 `validation/store/dust-production-store.png` 已读取，微尘、描边、灯光、景深与 NVG 提示同屏正常显示，没有检查样本标记。当前官方日志 398 行，无新增 shader/Lua 运行错误，检查仍因上述 DDS 返回 FAIL。58 个非数据 Lua 模块语法检查及 `git diff --check` 通过。

继续按 J 打开手机：`validation/store/dust-production-phone.png` 已读取，NVG 聊天/回复控件正常出现，右侧磨砂覆盖场景和微尘。该截图证明实际合成衔接，不是源版逐像素验收。

## 后续

继续校准主场景亚像素粒子；验证相同帧的整个场景、持续移动、倒带与剧情衔接。此前完整路线早于新后处理，仍需在当前正式入口重新通关。其余场景照明/阴影、音频/特效、存档跨重启、分辨率/触摸与逐场景 95% 验收仍未完成。
