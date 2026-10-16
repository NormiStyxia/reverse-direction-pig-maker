# 原生场景按钮迁移记录 · 2026-10-16

本轮将冻结 H5 的附近物体按钮与序章手机入口接入实际场景，使用原始 NVG；未引入 Yoga、DOM 或 WebView。SceneActions 直接读取现有剧情状态，按钮调用原版迁移后的 interact / togglePhone。第一章也已接入该组件，但本轮原生鼠标验收只覆盖序章。

## 已验证

- 冻结 CSS 的 12 个浏览器布局：宽度 1920、960、390、320，每种宽度分别 1、2、4 个附近选项。536 项检查通过，包含按钮尺寸、换行、手机位置及 DPR 1/2/3 下的输入。
- 剧情面板 42 次序章与 70 次第一章渲染模型检查、300 项冻结浏览器几何检查通过。增加场景按钮与剧情面板共享指针所有权检查：第二根手指不能抢占，ID 0 正常，拖动/失焦/尺寸变化取消点击。
- 本地 reload 9，PID 67687，2880×1566 物理像素 / 1440×783 逻辑像素 / DPR 2：实际鼠标点击手机图标打开群聊，角色切换持手机姿势；点击“伸手碰它”进入 fold。截图原分辨率保存，只去掉窗口标题栏。
- Lua LSP 0 Error；当前 Lua 运行日志 0 Error。官方 preview check 仍因启动时缺少 Cube/Day/DaySpecularHDR_QualityLow.dds 而 FAIL，不能宣称整个运行环境检查通过。

## 输入测试方式与证据边界

早期 CGEvent.postToPid 鼠标注入只观察到悬停，未收到引擎 MouseButtonDown/Up，因此这些截图不作为点击通过证据。tests/click-native-scene.py 已改为系统鼠标事件，发送前验证当前 Maker 会话 PID、前台应用和辅助功能命中元素所属 PID。不会点击覆盖在其他应用上的位置。开发入口保留 NATIVE_POINTER_DOWN/UP 日志，确认实际事件坐标为物理像素，与 input:GetMousePosition 一致。

有效截图：

- ../../validation/store/native-pig-action-os.png
- ../../validation/store/native-phone-open-os.png

完整回执：local-scene-actions-runtime-report.json。此次没有再次提交远端构建；先前授权的单次远端构建及拉取仍已完成。

## 未通过或尚未验收

场景按钮的合成粗体、内侧描边、手机阴影与 wiggle 动画仍需逐项视觉对照。布局与鼠标通过不等于真机触屏、移动端行走或全游戏相似度通过。手机毛玻璃、阴影接收偏移/滤波、完整后处理、其他剧情分支、持久化和全流程视觉验收仍待完成，未达到或宣称 95%。

本轮阴影 POSITION 接收偏移实验被当前 runtime 明确拒绝：Surface Shader v1 不支持该内建量。已恢复之前工作的应用着色器并重新生成各变体，未改引擎或 Technique。无效截图隔离到 validation/shadows/unsupported-position；该实验没有改善阴影的验收结论。
