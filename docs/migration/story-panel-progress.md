# NVG 剧情界面进展（2026-10-16）

本记录对应此前独立界面校验；2026-10-16 后续已将相同界面接到原生便利店和真实剧情状态，见 [便利店接入](store-render-progress.md)。仍不是可通关的完整移植，没有 95% 视觉验收结论。界面全部使用 raw NVG，没有 Yoga UI，也没有在游戏中嵌入 H5。

## 已实现

- `StoryOverlay.lua`：锁屏、群聊、头像/发言人、时间戳、消息气泡、输入框逐字打字、发送/删除、停电发送失败、商品卡片与瓶盖展示、旁白/念头、延迟出现的选择按钮。
- `StoryPanelLayout.lua`：按原 CSS 的逻辑像素布局；依据角色屏幕范围左右换位，保留 0.42/0.58 滞回；分辨率变化、触摸捕获、拖动取消和滚动范围处理。
- `StoryPanelMotion.lua`：0.32 秒消息进入、0.5 秒发送（65% 时略上冲和放大），按源 CSS 分段曲线计算。
- 本地加载真实冻结 WenKai 字体后才创建 NVG 字体句柄。修复 DWP 占位字体导致错误字宽被缓存：20px 数字原先被量成 20px，现在为 12px；首条消息文本 358px，加左右内边距后 384px，与冻结 H5 一致。图片也等待真实资源就绪，关闭界面后到达的回调不会复活资源。
- `PanelFixtures.lua` 从真实 `PrologueState` 的动作和时间推进产生六个快照：锁屏、群聊、失败发送、饭团、瓶盖、关东煮。没有把历史 c0 的商品支线混入序章。

低于 600px 的竖屏为可操作性增加最低可用面板宽度，最多 340px 且不超过视口减 16px；这是明确的移动适配偏差，需要真实移动端验收。

## 本轮验证

- `python3 tests/test_story_nvg.py`：PASS，6 个快照 × 7 个分辨率/DPR，共 42 次绘制，覆盖点击、发送打字门槛、多指/拖动取消、缩放、滚动、浏览选项延迟、异步加载/释放和动画关键帧。
- 同一测试使用字体文件的真实 advance，与独立 Chrome 渲染冻结 DOM 得到的尺寸进行对照：125 项坐标/尺寸检查通过。它验证排版计算，不等于像素相似度。
- Lua LSP：0 errors（2026-10-16 04:27:23）。
- 本地 runtime reload 7 / PID 70841：序章模型冒烟仍 PASS，3060 帧；`STORY_FONT_READY: digit 12.0; first message 358.0`。没有新增 Lua 错误。
- 使用进程定向 F7 输入切换并截图六个真实 NVG 界面，最后回到群聊。F8 返回标题。截图由 macOS 窗口捕获完成，未将 Maker 不支持的截图功能说成支持。
- 官方 `preview check` 仍为 FAIL：启动时找不到 `Cube/Day/DaySpecularHDR_QualityLow.dds`，发生在游戏脚本加载前。保留错误，没有把“画面能显示”写成官方检查通过。

## 对照证据与复现

`validation/panels/native-fixture-1..6-window.png` 是原始本地窗口截图；对应 `native-fixture-1..6.png` 只裁掉 32px macOS 标题栏，得到 1920×1080。`h5-fixture-1..6.png` 来自独立 headless Chrome，同尺寸/DPR、相同数据与背景，等待字体和图片加载后结束一次性动画。

`comparison-1..6.png` 三栏依次为 H5 / NVG / RGB 绝对差 ×4。`story-panel-comparison.json` 单独记录标题、内容、底部控制区的差值，没有计算会被空背景抬高的全图相似度。

复现顺序：

1. `python3 tests/export-panel-fixtures.py`
2. `python3 tests/panel-reference-server.py`（仅监听 127.0.0.1:8776）
3. `node tests/capture-panels.mjs`（使用独立临时 Chrome profile，不连接日常浏览器）
4. 本地 runtime 刷新到当前校验入口后，`python3 tests/capture-native-panels.py`
5. `python3 tests/test_story_nvg.py` 与 `python3 tests/compare-panel-captures.py`

## 尚未完成

六张原生截图已逐张查看；仍有字重/文本基线差异、头像大幅缩小时的锯齿、锁屏大时钟的基线和字距差异、卡片阴影与边角细节、正文换行规则细节。场景半屏压虚尚未接入。

下一阶段将界面接入便利店原生布景、角色/镜头、字幕、声效、灯光停电和折叠转场；继续实现第一章场景与流程、全部回响可视玩法、菜单/存档及端到端通关。当前图像只是单独界面对照，不能替代这些验收。
