# 便利店动态与序章收尾接入（2026-10-16）

状态：原生场景已接入自动门、灯管闪烁/停电、冷柜与熟食照明、树叶/店员/空椅子变化、桌上反转猪和七组布景折叠。界面继续使用 raw NVG，本轮没有远端构建或上传。**不是完整交付；阴影、后处理、回响与第一章尚未验收，不能给出 95% 相似度。**

## 冻结来源

仍为 commit 6a316e84907d8bc94ab59f20796685172b3535b5 的冻结副本。第一章调色未改，ch1-tuning.json 的 SHA256 检查通过。通过独立临时 Chrome 执行冻结 buildStore.update/fold 和 Pig 构造器，补导出原有动态对象句柄及桌上猪；没有更换成旧版标题、序章或素材。

新增猪网格后是 441 源节点、358 几何、203 材质、50 贴图，实际 1,169 个原生网格；774 个商品实例仍共享模型，颜色按材质/颜色缓存。

## 实现

- StoreDynamics.lua 保留源右手坐标，计算自动门接近/强制开门与关闭速度，店员摇摆、树叶风速、空椅子失真、随机闪烁、停电、熟食与冷柜灯光，以及七组布景的缩放/XYZ 旋转/枢轴位移。转换 Z/四元数只发生在 StoreRenderer。
- StoreRenderer 将模型输出接入原生节点和 SurfaceShader。8 个店内点光加 1 个桌上猪点光都使用冻结源的距离衰减；只有变动的光源参数才重新写入材质。停电保留冰柜和熟食灯，收银侧灯管仍亮，不能把整个场景直接调黑。
- 桌上猪直接导入冻结 Pig 的 1.55 米纸片和 pig-atlas-eight.png，保留底部挂点、0.42 初始比例、8 向反转帧、折叠时变大和自发光 1.0；冷色点光随剧情增亮。没有用标题页的单张猪替代。
- 档案盒涂鸦颜色与透明度随 doodleK/doodleGone 更新；真正的猪和档案盒独立。
- 显隐传播同时控制原生商品子节点上的 Drawable，避免只关源 Mesh 父节点而商品仍留在画面。
- StoreProbe 消费 doorForce、clearCaptions 和实际 finish 事件；F 交互可开始折叠。finish 目前只记录等待回响渲染接入，尚未连接下一场景。

## 验证

1. node tests/export-store.mjs --dynamics-only：独立 Chrome 内直接执行冻结 store.update/fold，记录 720 帧；覆盖不同 dt、门口接近、强制开门、高压力、闪烁、断电与 0–1 折叠。
2. python3 tests/test_store_dynamics.py：PASS，720 帧、70,560 项数值对照，2,072 次随机调用及分支顺序相符。数值误差门限 1e-9；不代表 GPU 通过。
3. python3 tests/test_store_visibility.py：PASS，13 次切换、5,733 源节点检查、15,197 Drawable 检查；覆盖祖先隐藏以及子节点自身的显隐保留。
4. python3 tests/test_store_geometry.py：PASS，355 模型变体、360 材质组、12,544 三角形、37,632 顶点；包括新增猪网格。
5. python3 tests/test_prologue.py：PASS，22,325 帧、21 场景、12 条浏览终止分支、3 次模型通关。
6. LSP 在 2026-10-16 05:47:50 报告 0 errors；git diff --check 通过。

本地 reload 19 / PID 91139 实际捕获停电、猪出现、折叠中段与末段。F4 使用真实剧情模型重放到指定阶段，但跳过中间 GPU 帧，**不是从标题到结束的实时通关**。之后实际按 F6 恢复、F 触碰猪，日志于 05:48:00 出现 STORE_PROBE_DONE。

reload 20 / PID 99920 使用修正类型注释后的代码，重新加载场景并捕获 F5 源版机位和猪阶段；当前没有 Lua 或 Shader 编译失败。官方 preview check 仍 FAIL：启动脚本前缺少 Cube/Day/DaySpecularHDR_QualityLow.dds。

截图：validation/store/store-dynamics-stages.png；逐张截图与日志详见 local-store-dynamics-runtime-report.json。另有一次输入后窗口从 1920×1080 变为 2560×1440，原因尚未确认；已保留该尺寸原图，不缩放混入同机位评分。截图工具现在清除测试键事件的继承修饰键，并从实际图形日志读取内容大小；适配验收仍未完成。

## 阴影能力差异与未完成项

尝试让屋顶/树叶遮挡片保留阴影而隐藏颜色时，reload 17 报错：built-in 'IN_SHADOW_PASS' is recognized but unsupported in UrhoX Surface Shader v1.。当前 dev-kit 文档支持此内建量，但安装 runtime 不支持。该改动已撤回，reload 18 起恢复正常材质。没有改引擎、生成的底层 Shader 或 Technique。

缺失的屋顶/树叶/百叶投影仍是严重视觉偏差；需要通过正式 runtime 能力或已支持的材质方案解决，不能宣称修复。原生折叠截图还暴露出背景灰蓝色和缺少最终墨迹遮罩，猪仍悬在原始背景上；源版收尾的 veil/haze/纸纹/景深等最终合成尚未移植。

其他待完成：外卖骑手及相关路径事件、蒸汽/雨/路灯光晕、声音、原字幕、回响渲染与衔接、第一章、存档菜单、触控和全分辨率覆盖、全流程端到端通关。下一步应接入收尾墨迹遮罩和回响场景，继续独立处理阴影运行端能力差异。
