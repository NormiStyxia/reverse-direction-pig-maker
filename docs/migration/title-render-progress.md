# 标题原生渲染进度 · 2026-10-16

已通过官方 Maker 插件提交 b9a32cd，并成功构建 preview/title.lua（55 秒，preview refresh HTTP 200）。实际引擎画面仍未验证。

- TitleState：原版 update 逐帧对照 10,240 帧通过。包含开场、5–10 秒自动等待、0.75/0.5 秒扰动、5 秒线稿停留、K 倒带和离场时序。
- TitleParticles：600 帧、277,200 个顶点分量通过；Float32 最大差 1.1920928955078125e-7。
- TitleRenderer：原生 Scene / CustomGeometry / SurfaceShader；2 个源版公式移植 shader、3 个材质、2 个预乘纹理衍生副本。原图未修改。
- 已构建的 b9a32cd 校验入口只含底图和粒子；本轮新增原生 NVG 文字、表盘、菜单，尚未连接剧情。
- LSP watch 诊断 0 errors；单次 check 模式缺 emmylua_check，所以使用官方工具的 watch 模式，未禁用诊断。
- 旧模块工厂改为 init 字段初始化以供 LSP 推导；所有原有逻辑对照和输入路线测试通过。

## 验证缺口

构建成功不是运行成功。官方日志 watcher 尚未收到 runtime.log，state.json 曾出现 query_runtime_logs 返回不含 logs array；03:07 +08:00 查询已恢复，仍返回 0 条日志。成功构建后本地 .project 配置仍缺失，未为此重复构建。

用户于 2026-10-16 明确要求界面只用 NVG、不使用 Yoga UI，已按此实现。下一步：实际引擎检查着色器编译、UV 朝向、sRGB/线性处理、预乘透明边缘、精灵顺序、20:9 裁切和 DPI。仍需完整序章/第一章场景、剧情、音频、存档与端到端通关。没有 95% 相似度结论。

## 工具状态

Cindy 插件表面未暴露本地预览工具。用户明确要求本地 runtime 后，按随包 taptap-maker-local skill 使用同一官方 bundle 的 preview status/start/refresh/logs/check；不安装独立 CLI、不上传。此本地流程已经实际启动，不能再沿用“无法本地预览”的旧判断。


## 原生 NVG 界面 · 2026-10-16

- 删除未提交的 Yoga TitleUI 及 widget 测试；用户脚本无 urhox-libs/UI、UI.Init 或 Yoga 依赖。
- TitleOverlay 直接拥有 NVG context、字体、图片；TitleVectors 直接绘制路径，在 NanoVGRender 事件绘制。不依赖原生 SVG API。
- 2560×1152 固定设计空间 contain；绘制与鼠标/触摸输入共用 DPR/居中变换，窗口及 DPR 变化后重算。
- 包含菜单选择条、猪光标旋转、选关/设置面板、按住 K 提示、时钟、离场遮罩、标题反向展开/翻转及表盘/蓝图动画。
- 输入具备按下/松开匹配、锁定行、面板隔离、多指捕获、焦点/缩放取消；跳过开场的触摸不触发新游戏。
- title-nvg-test-report.json：PASS，24 组 viewport/DPR、输入及 NVG 生命周期适配器测试；不是实际引擎像素测试。
- 原标题 10,240 帧差分、粒子 600 帧 / 277,200 分量差分再次 PASS；LSP 0 errors。

### 明确未完成的视觉细节

标题五字采用源版 macOS Songti SC Black 的矢量轮廓，不包含系统字体文件。其余文字暂用引擎 NotoSansSC，尚未达到原版 PingFang/mono/宋体的字体一致性。面板 backdrop blur、标题外发光、猪光标 drop-shadow 尚未复刻，菜单文字颜色/透明度过渡仍需精调。NVG 路径像素、透明混合和真实截图均待验证。不能以这些适配器测试替代运行证据，不能据此宣称 ≥95%。


## 本地 Runtime 验证 · 2026-10-16

用户明确要求本地优先，不反复上传。最后一次远端提交为 82d70ad，构建成功，但 preview-refresh 返回 fetch failed。此后所有修复只在工作区和本地受管理预览副本中，未再次提交远端。

正式本地入口：随 Cindy 插件发布的 vendor/taptap-maker/dist/maker.js，使用系统 node 执行 preview 命令，明确 --target-dir 指向本工作区。本机已有 Runtime（登记安装 2026-09-29），不需要下载/安装。官方 prepare 在受管理副本构建，保留源工程，首次耗时 94.86 秒。

- 首次启动：缺 nvgSvgCreate；Metal/HLSL 编译不支持双参数 atan。改为 raw NVG 路径和单参数 atan 的象限等价计算。
- 第一轮刷新：03:39:04 标题脚本实际打印 raw NVG paths 的启动标志；不再有 Lua SVG API 错误。标题底图 shader 的辅助函数内纹理采样别名不可见，第二轮将原剪影函数计算原样内联到 fragment。
- 前向渲染路径显式选定；CustomGeometry 在绑定材质前分配 slot，首次 Commit 前保持隐藏。适配器测试 120 帧 / 12 drawable PASS。
- 引擎启动本身报告 Cube/Day/DaySpecularHDR_QualityLow.dds 缺失，发生于 game 脚本加载前；不能将 check FAIL 报成验收通过。
- 本地 session 为 fa6bf3f4-f069-471e-b264-2c39c9194da0。读当前 preview status/logs/check，勿混用远端 .maker/logs/runtime。
- 本地 CLI 尚无截图/自动输入能力。已通过 macOS CoreGraphics 查询本轮 Runtime PID 对应窗口，并用系统 screencapture 捕获该窗口、读取截图；不是 CLI 截图能力。仍未自动化输入与通关。


### 第二轮刷新结果

2026-10-16 03:41:27，两个标题 pixel shader 均加载成功；本轮无 Lua 执行错误、shader 编译错误或空顶点缓冲错误。原生窗口（PID 98079 / window 20293）截图已读取，能看到标题、菜单、表盘及成稿→扰动剪影→线稿变化。截图位于 validation/local-title/，finished-comparison.jpg 是同尺寸裁切对照（动画时间未同步，不能用于相似度定量验收）。原版标题字体外发光、正文等宽字体与当前有明显差异，完整迁移未通过验收。

preview check 仍为 FAIL：runtime 启动阶段缺 Cube/Day/DaySpecularHDR_QualityLow.dds，未隐藏或忽略该结果。详见 local-title-runtime-report.json。工作区当前修复未上传，保留本地窗口运行以供查看。
