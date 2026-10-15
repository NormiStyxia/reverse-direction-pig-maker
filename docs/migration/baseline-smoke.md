# 冻结 H5 基准复测（2026-10-16）

独立无头 Chrome，Metal，1280×720，deviceScaleFactor=1，直接读取已核验的冻结离线 HTML。
通过源工程 cdp-check.mjs 执行 tests/baseline-title-steps.json；未修改源工程。

标题加载与 Enter 进入完整便利店入口成功，捕获异常和 console error 为 0。
截图已读取：validation/h5-1280x720/title.png、prologue.png；原始日志在同目录 browser-validation.json。
标题截图存在标题文字在右侧显示不完整的现象；这是本次 H5 捕获结果，尚未区分进入动画时刻与稳定布局原因。后续必须固定动画时钟再核查，不能用这帧判定目标适配合格。
便利店截图可见原角色、货架、玻璃窗、前景景深和手机入口。

这是 H5 冒烟，不是完整通关；没有 UrhoX 运行截图，未计算视觉相似度。
