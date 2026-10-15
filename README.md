# 反方向的猪 · UrhoX 迁移

当前为迁移中的 Maker 工程，**不是完整移植交付**。已有原生标题底图/粒子渲染校验入口，尚未通过引擎视觉验收。

Maker 工程 ID：1a737f5b-265f-4977-abf1-a9721b9582e6。
唯一源基准：chapter1 6a316e84907d8bc94ab59f20796685172b3535b5，加冻结工作树的 config/ch1-tuning.json。任务要求见 [迁移任务](docs/migration/迁移任务.md)。

已完成：冻结指纹核验、原始资源与配置导入、6+5 层关卡数据的 Lua 导出，以及倒带时间线、箱子/货架模拟、三种时间合体、倒带阻挡与压板/门的 Lua 移植和源版差分检查。第一章 paper=false；调色未用 Git HEAD 默认覆盖。

尚未完成：UrhoX 游戏入口、场景与渲染、标题、剧情/输入/音频/存档集成、完整回响玩法、全流程通关、分辨率适配与视觉验收。没有 95% 相似度结论。

## 开发环境（2026-10-16）

官方 maker_init 已成功补齐 AI dev kit 20261015-132558，前期下载超时已恢复。
AGENTS.md、engine-docs、examples、templates、urhox-libs 均已安装。
渲染校验入口为 scripts/preview/title.lua，仅验证开场底图、动态粒子、猪与 K 键倒带。标题文字、表盘、可见菜单和剧情尚未接入此入口。正式游戏入口尚未完成；构建状态见 docs/migration/environment-status.json。

本会话已于 2026-10-16 收到持续目标任务，后续按目标继续推进。此前工具未提供切换开关；没有调用或伪造开关成功回执。

## 已有模块与检查

- scripts/game/data/Levels.lua：冻结源的 11 层数据；Lua 容器下标从 1 开始，但 plates / exitPlates 内的引用数值保留原版从 0 开始，消费时显式加 1。
- scripts/game/data/Tuning.lua：两份原始渲染配置。
- scripts/game/PigController.lua：移动、冲撞、八向帧、身体姿态和残影。
- scripts/game/EchoPlayer.lua：冲撞接触判定、擦边限制与玩家碰撞。
- scripts/game/EchoRun.lua：展开、可操作阶段、重开、过关转场；仅连续输入的两条首关路线已通过无渲染集成测试。
- scripts/game/EchoSimulation.lua：可游玩阶段的纯模拟；死局提示、完整剧情与渲染尚待接入。事件由表现层消费，整局只提示一次的语义仍需表现层处理。
- scripts/game/Timeline.lua：原版 0.3 秒空闲压缩、90 秒历史限制、部分回退和阻挡规则。
- scripts/game/TitleState.lua：标题动画/菜单纯状态；10,240 帧源版对照通过。
- scripts/game/TitleParticles.lua：羽毛、小鸟和猪轨迹；600 帧、277,200 个顶点分量源版对照通过。
- scripts/render/TitleRenderer.lua：UrhoX CustomGeometry + SurfaceShader，保留原画、噪声/扰动公式、视差和遮挡。
- tests/export-title-shaders.py：从冻结版着色器生成 SurfaceShader，并生成匹配 WebGL 预乘上传的纹理副本；原图不修改。GPU 色彩、透明边缘仍待实测。
- 坐标仍是源版右手坐标；未来渲染适配器统一转换 Z，逻辑不要重复转换。
- assets/：原始素材；assets/config/：原始配置。
- reference/：仅本地构建/测试参考，忽略提交；绝不作为游戏内 H5/WebView 运行时。

重新导入（要求安装 Node.js）：

    node tests/import-baseline.mjs '/Users/xd/Desktop/【线上 诺米AI乱炖项目组 反方向的猪】/documents/2026-10-16-UrhoX迁移交接'

纯逻辑对照（Python 3、lupa、Node.js）：

    python3 tests/test_migration.py
    python3 tests/test_echo.py
    python3 tests/test_player.py
    python3 tests/test_contacts.py
    python3 tests/test_echo_run.py
    python3 tests/test_title.py
    python3 tests/test_title_particles.py

各项测试报告见 docs/migration/*-test-report.json。测试使用本机 Lua 5.4，不能替代引擎内运行验证。构建和预览使用 Cindy 的 TapTap Maker 插件。
