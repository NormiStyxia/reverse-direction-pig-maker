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

当前 Cindy Maker 插件没有提供本地预览或截图工具；不能改用独立 CLI、直接 MCP 或普通浏览器绕过。读取官方 build 返回的本地日志路径是允许的。后续需要实际运行证据，不能用 Lua 单元测试替代。


## 原生 NVG 界面 · 2026-10-16

- 删除未提交的 Yoga TitleUI 及 widget 测试；用户脚本无 urhox-libs/UI、UI.Init 或 Yoga 依赖。
- TitleOverlay 直接拥有 NVG context、字体、图片和原生 SVG 实例，在 NanoVGRender 事件绘制。
- 2560×1152 固定设计空间 contain；绘制与鼠标/触摸输入共用 DPR/居中变换，窗口及 DPR 变化后重算。
- 包含菜单选择条、猪光标旋转、选关/设置面板、按住 K 提示、时钟、离场遮罩、标题反向展开/翻转及表盘/蓝图动画。
- 输入具备按下/松开匹配、锁定行、面板隔离、多指捕获、焦点/缩放取消；跳过开场的触摸不触发新游戏。
- title-nvg-test-report.json：PASS，24 组 viewport/DPR、输入及 NVG 生命周期适配器测试；不是实际引擎像素测试。
- 原标题 10,240 帧差分、粒子 600 帧 / 277,200 分量差分再次 PASS；LSP 0 errors。

### 明确未完成的视觉细节

标题五字采用源版 macOS Songti SC Black 的矢量轮廓，不包含系统字体文件。其余文字暂用引擎 NotoSansSC，尚未达到原版 PingFang/mono/宋体的字体一致性。面板 backdrop blur、标题外发光、猪光标 drop-shadow 尚未复刻，菜单文字颜色/透明度过渡仍需精调。SVG 原生绘制、透明混合和真实截图均待验证。不能以这些适配器测试替代运行证据，不能据此宣称 ≥95%。
