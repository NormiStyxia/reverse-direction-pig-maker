# 反方向的猪 · UrhoX 迁移

当前为迁移中的 Maker 工程，**不是完整移植交付**。NVG 标题已连接原生便利店、六层回响、第一章会议室/办公区、五层回响、09:58 与结尾重玩。剧情和解谜输入已通过冻结源码对照；照明、阴影、后处理、声音、触控与完整视觉验收仍未完成。

Maker 工程 ID：1a737f5b-265f-4977-abf1-a9721b9582e6。
唯一源基准：chapter1 6a316e84907d8bc94ab59f20796685172b3535b5，加冻结工作树的 config/ch1-tuning.json。任务要求见 [迁移任务](docs/migration/迁移任务.md)。

已完成：冻结指纹核验、原始资源与配置导入、6+5 层关卡数据的 Lua 导出，以及倒带时间线、箱子/货架模拟、三种时间合体、倒带阻挡与压板/门的 Lua 移植和源版差分检查。第一章 paper=false；调色未用 Git HEAD 默认覆盖。

本地原生自动输入已连续走通标题到结尾的一条完整路线（done 回答、全部 11 层），见 [完整路线记录](docs/migration/full-route-progress.md)。尚未完成其余分支的原生验收、世界背景/粒子/音频、阴影/后处理与原版表现细节、鼠标/触控和多分辨率实际游玩、跨重启存档持久化。没有 95% 相似度结论。存档与菜单当前证据见 [存档进展](docs/migration/save-progress.md)。

## 开发环境（2026-10-16）

官方 maker_init 已成功补齐 AI dev kit 20261015-132558，前期下载超时已恢复。
AGENTS.md、engine-docs、examples、templates、urhox-libs 均已安装。
本地校验入口为 scripts/preview/title.lua，包含标题、两章剧情和全部 11 层回响。开始游戏进入原生便利店，WASD 移动、J 手机、F 交互、Tab 选择；回响中 J 冲撞、K/Shift 倒带、R 重来。开发入口保留诊断热键与检查文字，尚非最终交付入口。模型日志通过不代表剧情画面完成；构建状态见 docs/migration/environment-status.json。

本会话已于 2026-10-16 收到持续目标任务，后续按目标继续推进。此前工具未提供切换开关；没有调用或伪造开关成功回执。

当前预览默认显示标题；Enter 开始，F6 可直接进入便利店，进入后 F4 检查停电/猪/折叠阶段、F5 固定对照机位、F6 暂停/继续，F8 返回标题。标题中 F8 打开独立 NVG 校验页，F7 切换六个快照。六组界面对照、42 组绘制与输入检查、125 项冻结 DOM 排版对照已完成；几何导入另通过 37,626 个顶点检查。便利店人物发黑、商品失色、档案盒提前显示已修正；照明已有 8 个区域同机位对照，阴影和最终后处理仍未验收。自动门、停电、桌上反转猪和布景折叠现已接入，720 帧场景动态源版对照通过；见 [动态接入记录](docs/migration/store-dynamics-progress.md)。详见 [便利店接入进展](docs/migration/store-render-progress.md) 和 [剧情界面进展](docs/migration/story-panel-progress.md)。

## 已有模块与检查

- scripts/game/data/Levels.lua：冻结源的 11 层数据；Lua 容器下标从 1 开始，但 plates / exitPlates 内的引用数值保留原版从 0 开始，消费时显式加 1。
- scripts/game/data/Tuning.lua：两份原始渲染配置。
- scripts/game/PigController.lua：移动、冲撞、八向帧、身体姿态和残影。
- scripts/game/EchoPlayer.lua：冲撞接触判定、擦边限制与玩家碰撞。
- scripts/game/EchoRun.lua：展开、可操作阶段、重开、过关转场；六层与五层完整输入路线均通过冻结源码对照，并已分别在本地原生窗口实时重放通过。
- scripts/game/EchoSimulation.lua：可游玩阶段的纯模拟；死局提示、完整剧情与渲染尚待接入。事件由表现层消费，整局只提示一次的语义仍需表现层处理。
- scripts/game/Timeline.lua：原版 0.3 秒空闲压缩、90 秒历史限制、部分回退和阻挡规则。
- scripts/game/TitleState.lua：标题动画/菜单纯状态；10,240 帧源版对照通过。
- scripts/game/TitleParticles.lua：羽毛、小鸟和猪轨迹；600 帧、277,200 个顶点分量源版对照通过。
- scripts/game/PrologueState.lua：23:38 便利店剧情状态、工作群消息、6 项商品浏览、停电/遇猪/折叠交接；22,325 帧源版对照通过，覆盖 12 条商品终止分支与 3 次模型流程完成。详见 docs/migration/prologue-progress.md。
- scripts/game/NormiController.lua：人形纸偶移动、惯性、碰撞、坐姿/手机姿势与动作；逻辑保留源版坐标，已接入原生角色网格。
- scripts/game/StoreDynamics.lua：门、灯光、风、空椅子和七组布景折叠；720 帧、70,560 项源版数值对照通过。
- scripts/game/EchoRain.lua：六层回响各 600 条原生雨线，下落/倒带上升/越界重生；1,440 帧、392,832 项源版检查通过。出口透明混合已用源版线性离屏管线核对，局部指标见 docs/migration/echo-transparency-comparison.json，不代表整游戏视觉验收。
- scripts/render/StoreRenderer.lua：冻结便利店几何/材质导入、共享 StaticModel、角色与镜头；光照和后处理未验收。
- scripts/game/BrowseState.lua：商品条目依次显示及选择按钮延迟，供 NVG 绘制消费。
- scripts/render/TitleRenderer.lua：UrhoX CustomGeometry + SurfaceShader，保留原画、噪声/扰动公式、视差和遮挡。
- tests/export-title-shaders.py：从冻结版着色器生成 SurfaceShader，并生成匹配 WebGL 预乘上传的纹理副本；原图不修改。GPU 色彩、透明边缘仍待实测。
- 坐标仍是源版右手坐标；渲染适配器统一转换 Z，逻辑不要重复转换。
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
    python3 tests/test_prologue.py
    python3 tests/test_story_nvg.py
    python3 tests/test_store_geometry.py
    python3 tests/test_store_visibility.py
    python3 tests/test_store_dynamics.py
    python3 tests/test_chapter1.py
    python3 tests/test_story_route.py
    python3 tests/test_save.py
    python3 tests/test_chapter_end.py

各项测试报告见 docs/migration/*-test-report.json。测试使用本机 Lua 5.4，不能替代引擎内运行验证。构建和预览使用 Cindy 的 TapTap Maker 插件。

序章六层原生回响与便利店收尾已接通，完整六层控制输入路线和冻结源重放通过；仍未完成视觉/全流程验收。当前进度与本地诊断入口见 [回响接入记录](docs/migration/echo-render-progress.md)。

原生镂空投影与落地阴影已修正并完成局部对照；全游戏视觉仍未验收。详见 [阴影校准记录](docs/migration/shadow-progress.md)。
