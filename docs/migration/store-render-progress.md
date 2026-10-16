# 便利店原生场景接入（2026-10-16）

状态：标题的新游戏已连接原生便利店 + 实际 PrologueState + NVG 手机/商品界面。2026-10-16 最新动态接入见 [停电、猪与折叠进展](store-dynamics-progress.md)，下文 reload 10/16 为阶段记录。可通过键盘移动和交互，但仍是开发校验入口，**不是完整交付，视觉未通过，不能给出 95% 相似度**。

## 准确资源导入

通过独立临时 Chrome 执行冻结源码的 buildStore()、Normi 和 Canvas 绘图，离线导出场景数据。Three.js、浏览器及参考截图均不进入 UrhoX 游戏运行时。冻结源码未修改。

- 440 个源节点、357 份几何、202 份材质、49 张贴图；774 件商品保留实例矩阵和逐件线性颜色；运行端通过按材质/颜色缓存的 uniform 材质变体消费颜色。
- 原始图片复用已导入文件并校验 SHA256；程序绘图保存无损 PNG，包含店招、时钟、墙面/地板纸纹、包装、百叶与其独立 alphaMap。
- 导入保留父子层级、局部位置/四元数/缩放、多材质组、阴影与可见性标志。源右手坐标保留在数据，StoreRenderer 统一翻转 Z、四元数 x/y、三角形绕序和 UV 的 V。
- 共享网格通过 CustomGeometry:FillModel() 创建后复用，商品使用 StaticModel 共享模型与线性颜色 uniform；本地实际加载 1,168 个网格。
- 固定导出随机种子 0x6a316e84，便于重现。它不是宣称与任意随机运行的 H5 像素完全相同。
- 冻结 ch1-tuning.json 的哈希仍是 1dae5f70540d5606ba113498d202bf45175721f817c8ef983669adf0ef8101a9。第一章 paper=false 未改变。

## 已接通的运行行为

- 当前预览默认标题。Enter 的 new 事件进入 StoreProbe；F6 可直接进入便利店，进入后 F5 固定源版对照帧、F6 暂停/继续；F8 返回标题调试视图（菜单恢复/新周目状态还未正式实现）。
- WASD/方向键使用源 main.js 的 driveHuman 语义：归一方向前方 0.8 米目标，松手调用 release()。复用 NormiController 的碰撞、惯性和姿势。
- 角色图集帧、挂点、翻面和走路摇摆；相机复用 24° FOV、22 米距离、16°俯仰及 3.2 跟随速度。镜头/角色仅覆盖当前序章正常阶段。
- J/Space 开关手机，F 交互，Tab 选择附近交互，Esc 收起；NVG 手机/浏览界面按实际角色投影选择左右侧。
- 档案盒按剧情出现、时钟指针按剧情时间更新。临时字幕与说明是调试 HUD，**尚未复刻原字幕样式/位置/计时**。
- 标题选择回响、存档读取、折叠后切回响和第一章尚未连接。

## 早期接入验证（reload 10，历史记录）

- python3 tests/test_store_geometry.py：PASS，354 种共享模型/359 材质组，12,542 个三角形、37,626 个顶点的坐标/法线/UV 对照通过；检查多材质、共享对象、有限数值和冻结配置指纹。不是 GPU 视觉验收。
- python3 tests/test_story_nvg.py：PASS，42 个绘制/输入组合和 125 个冻结 DOM 几何对照仍通过。
- LSP 在 2026-10-16 05:06:26 报告 0 errors；git diff --check 通过。
- 本地 runtime reload 10 / PID 33474：STORE_NATIVE_READY: 440 source nodes, 1168 native meshes; 6 particle/billboard objects pending。实际按 Enter 从标题进入、D 右移、J 打开手机，并捕获截图；截图中镜头随移动、手机按角色位置换侧。
- 本轮最新游戏/Lua 日志没有脚本失败或 Shader 编译失败。官方 preview check 仍 FAIL，原因是游戏脚本加载前缺少 Cube/Day/DaySpecularHDR_QualityLow.dds；不隐去该错误。
- reload 9 曾使用开发文档声明的 Material:GetShaderParameter() 做诊断，实际安装的 runtime 没有该方法，导致资源回调中断；reload 10 已去掉该调用并重新验证场景加载。

## 2026-10-16 照明与可见性修正（reload 16）

当前完整前向路径为 EngineRes/RenderPaths/CEMapSSAO.xml。此前只使用基本 Forward.xml；reload 11 的路径缺前缀、reload 12 的 Lua assert 多返回值传参错误均已修正。没有修改引擎或后端生成的 Shader。

- 已读取安装 runtime 的 SurfaceLight.glsl：EMISSION 只在 AMBIENT 条件分支相加。StoreLit 使用 ambient_light_disabled 时，人物和家具发黑；移除此标记并保持 Zone 平坦环境色为黑之后，同机位 reload 14 截图确认恢复颜色。开发文档声称该开关保留自发光，与此安装版本实际行为不一致。
- 半球光按冻结 Three 的 sky/ground 插值和 BRDF_Lambert 的 1/pi 计算。保留源线性颜色，不额外 gamma 转换。
- 8 个无阴影点光使用源码 getDistanceAttenuation 的距离幂次、范围四次方软截断和三段 ramp，在原生 SurfaceShader 中逐点计算；点光组件保留状态但禁用绘制，避免重复累加。太阳仍使用原生 Light 与阴影路径。动态闪烁/停电参数更新尚未接入，不能据静态照明声称完整剧情照明完成。
- 本机默认 COLOR 路径未显示商品实例颜色。改用按源材质/线性颜色缓存的克隆材质 instance_tint，几何仍共享；reload 15 实际截图确认彩色饮料/杯子/包装恢复。
- H5 导出 Normi.update(0) 会用构造器边界把初始 Z 限制到 -4，而实时剧情边界不同。F5 对照帧使用导出的实际角色变换，实时控制仍走原状态机。
- UrhoX Node.enabled 只控制直接组件，不继承祖先状态。新增源版可见性传播，保留各子节点自身 visible；修正档案盒未解锁却提前显示。reload 16 实际截图确认桌面档案盒隐藏。
- python3 tests/test_store_visibility.py：PASS，13 次显隐切换、5,720 个节点断言，覆盖档案盒出现/消失、隐藏祖先、父子独立显隐。
- 几何回归仍 PASS：354 模型变体、359 材质组、12,542 三角形、37,626 顶点。LSP 2026-10-16 05:28:53 为 0 errors。
- reload 16 / PID 69586，本地实际加载 1,168 网格并捕获 F5 对照帧；无当前 Lua/Shader 编译错误。官方 preview check 仍为 FAIL：启动阶段缺少 Cube/Day/DaySpecularHDR_QualityLow.dds。

## 视觉差异：尚未验收

最新截图 validation/store/native-store-lighting-final-reference.png 与 h5-raw.png 使用相同相机和源角色变换；对照图见 lighting-regions.png。python3 tests/compare-store-captures.py 对人物、冷柜、前景货架、熟食柜、窗墙、桌面投影、地面和窗外植被分别计算像素误差，没有总体相似度，也没有验收通过结论。

当前最明显问题仍是百叶窗、树叶和屋顶遮挡的阴影。桌面/地面投影区域约 39.22% 像素至少一个通道的误差大于 32/255，窗外植被约 37.67%；这些是差异诊断，不能转成“相似度百分比”。人物边缘/色调、窗外地面夜景、源最终后处理也未匹配。后续应先检查仅投影物体使用 viewMask=2 是否被活动相机 viewMask=1 排除，以及 alpha-discard 的辅助投影，而非增加亮度。

以下为 reload 16 时的待办；自动门/灯光/桌上猪/折叠等已在后续完成原生接入，仍须视觉验收，见动态进展。其余未完成：

- 源太阳/点光衰减、半球光、分段 ramp 的 GPU 对照；纸偶最终亮度封顶、阴影透明孔及背面投影核验。
- 门开合、店员摆动、路人、灯管闪烁/停电、桌上猪、灯/布景折叠、树影动态、熟食灯和蒸汽。
- 6 个粒子/公告板对象有明确遗漏记录：4 个路灯光晕 Sprite、1 个蒸汽 Points、1 个雨 LineSegments（序章晴夜初始隐藏）。没有用实体面片默默替代它们。
- 夜景 shader 已翻译天空/树/树篱分支；ground 的夜景处理仍待适配到受光材质。需验证风、透明边缘、半屏模糊、纸感、描边、DOF、Bloom、调色与音频。
- 正式触控移动、失焦释放、所有分辨率、存档/菜单、完整回响与第一章流程和端到端通关。

## 复现与证据

1. python3 tests/store-reference-server.py（127.0.0.1:8777，仅读冻结副本）
2. node tests/export-store.mjs（独立 headless Chrome，临时 profile）
3. python3 tests/import-store.py；python3 tests/export-store-shaders.py
4. python3 tests/test_store_geometry.py
5. 按官方本地预览流程刷新。python3 tests/capture-native-store.py NAME 可截当前窗口；额外参数是 macOS 定向测试键码，见脚本说明。

validation/store/h5-raw.png 只是同源场景关闭原后处理的几何/灯光检查图，初始固定机位；历史 native-store-current.png 是已走完开场的跟随机位，不能打分。新 native-store-lighting-final-reference.png 使用 F5 固定机位，但仍只覆盖 raw 场景，不能当作完整 95% 验收。

导出清单：store-export-report.json；几何测试：store-geometry-test-report.json；显隐测试：store-visibility-test-report.json；区域差异：store-lighting-comparison.json；运行记录：local-store-runtime-report.json。没有远端构建、提交或上传预览。
