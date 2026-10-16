# 蓝白衔接与倒带保色 · 2026-10-16

已接通冻结版 main.js 的标题 → 游戏蓝白转场和 rewind-levels.js 的倒带变色。整游戏视觉相似度尚未验收，不能报告达到 95%。本轮仅使用本地 runtime，没有远端提交。

## 实现

- SceneBridge 对应 startBridge/updateBridge：蓝白起步，1.8–4.8 秒 smootherstep 逆时针扫回原色，5.2 秒镜头从 1.22 倍回归 1 倍。保留原版“先更新相机，再产生下一帧桥接距离”的顺序。
- 只在标题的新游戏/回响选择回调启动桥接；故事正常进入回响、回响换层不重新触发。暂停、失焦、加载不消耗桥接时间；倒带使用 EchoPose.rwK × 0.6。第一章仍继承冻结 paper=false 调色。
- PresentSelection 按原始关卡定义、序列化节点与 handles 重建 markPresent，排除带透明贴图/alphaTest 的纸片及 Sprite，包含未显现的 now 合成箱。没有把所有透明几何简单当成实心物体。
- PresentMask 复用原生几何与父节点变换，在独立 bit 4 视图写出可读深度；main=1、shadow=2 保持原用途。最终合成将 reverse-Z 转回相同深度方向，再按源公式判断可见物件是否保留原色。关闭蓝白时不渲染此目标。
- 保留前轮独立主场景深度和消费者先注册的渲染顺序；新深度目标使用相同解绑、先回收 surface wrapper、再释放 texture 的生命周期规则。
- 实际标题进入曾出现资源加载黑场：旧 Application 在 start 事件后立即停止渲染/更新标题。新增 raw NVG 纸白封面，场景加载期间保持，场景就绪后按标题原有 0.9 秒根透明度淡出。正式入口仍为 main.lua，不暴露测试入口或调试按键。

## 检查与证据

- tests/test_scene_bridge.py：直接执行冻结 main.js 函数，与 Lua 同样输入逐帧比较，8,361 帧 PASS。
- tests/capture-present-selection.mjs + tests/test_present_selection.py：独立 Chrome 从冻结 buildLevel 得到真实 Three layer 标志；6 个序章回响 + 第一章 3 回答 × 5 层共 21 个场景，保色几何名单完全一致。参考文件未被修改。
- tests/test_scene_post.py：246 项 PASS；5 种尺寸，177 个 surface wrapper 均先于父纹理回收，涵盖保色深度绑定、缩放、停用时不提交和销毁。
- tests/test_scene_style.py：5,029 项 PASS；保留源 4 Hz 笔触与两份调色。新增代码 Lua 语法通过；LSP 0 errors，见 validation/blue/lsp-final/；git diff --check 通过。
- tests/test_title_nvg.py：24 组分辨率/DPR，包括纸白封面、信箱区域与淡出透明度。没有 Yoga 依赖。

原生固定画面：session 0e8a692e-0aa1-469c-b1ee-2135b07d6cc6 / reload 29 / PID 7450 / 1920×1080，文件在 validation/blue/native-final/，已实际读取 contact-sheet.png。

- 便利店蓝白、扫场中点和原色均可见。
- 序章第五层中，打开保色遮罩影响 22,178 个像素；这些像素与关闭蓝白时的原色截图逐像素完全相同。
- 将箱子和圆板放到地板下方、仍在视锥内但完全被遮挡，遮罩开/关差异为 0 像素。
- 同一进程由便利店 → 序章回响 → 第一章回响，画面实际渲染，无新增 Lua/shader 错误或释放崩溃。该项为测试跳转，不是完整通关。

可复跑图片报告：tests/report-blue-rendering.py；结构化结果：blue-rendering-report.json。缩略联系表只用于看图，数值比较使用原尺寸图片。

正式入口复验：reload 31 / PID 13709，实际 Enter 进入便利店；37 张墙钟采样覆盖纸白等待 → 淡入蓝白 → 原色剧情，已读取联系表。修正前 reload 30 有一张超过 99% 像素近黑的样本；修正后 37 张中为 0，见 blue-title-cover-report.json。这是采样结果，不是逐帧无黑帧保证。当前运行保持 main.lua，未留在独立测试场景。

## 限制和后续

- 原版保留了 0.00002 深度容差。早期靠近地板的遮挡样本有 188 像素细线仍保色；更深且确定完全遮挡的样本为 0。近交界处需要与 H5 同机位对照，不能用后者替代前者的边缘验收。
- 首次 live-title 采样暴露黑场，保存在 validation/blue/live-title-before-cover/；修正后的采样单独存放 validation/blue/live-title/。系统截图耗时超过预设间隔，必须以 receipt 中实际墙钟时间为准，不能称作 25/60 fps 视频。
- 官方 preview check 仍因既有 Cube/Day/DaySpecularHDR_QualityLow.dds 缺失返回 FAIL。没有将此算作本轮渲染回归通过。
- 尚需独立近景模糊/溢出、其余渲染细节、持续运动/倒带与完整流程的 H5 同机位比较、性能与触控/分辨率适配，以及跨重启存档验证。当前仅是明确范围的渲染接入和回归。

冻结调色 SHA256 仍为 1dae5f70540d5606ba113498d202bf45175721f817c8ef983669adf0ef8101a9。
