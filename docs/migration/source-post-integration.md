# 原版后处理与正式入口 · 2026-10-16

> 2026-10-16 后续更新：章节→早晨→标题→序章回响的原生切换已在 session 0e8a692e-0aa1-469c-b1ee-2135b07d6cc6 / reload 1 跑通，未重现先前的 surface 析构崩溃，但不代表全流程/缩放压力测试完成。用户随后指出严重描边抖动；已修正第一章 4 Hz 继承和深度像素中心采样，随后移除描边中的临时屏幕深度读取，改用独立颜色/深度目标；固定会议室同节拍连续帧已无额外变化，移动镜头验收仍未完成，详见 outline-jitter-report.json。下面保留先前接入记录作为历史，当前默认入口仍为 main.lua。

本轮把冻结 post.js 的效果接进正常游戏流程，界面仍是 raw NanoVG，未修改引擎或使用 Yoga/WebView。**尚未完成 95% 相似度及全流程验收。**

## 当前代码

- 正式入口为 main.lua，协调逻辑在 game/Application.lua。preview/title.lua 兼容旧的普通入口。preview/diagnostics.lua 才显式启用开发功能。
- 普通入口禁止 F1–F12 诊断操作，不执行启动存档/剧情 smoke，不创建假聊天校验面板，不显示校验横幅、调试操作提示、内部阶段或鼠标日志。真实剧情字幕、操作提示和 NVG 交互仍保留。
- 主场景输出独立 RGBA16F 颜色与可读深度 attachment。SceneStyle 将相机与画风参数分别传给独立 STYLIZE / DOF pass；描边使用明确绑定的主场景深度，保留八邻域描边、源墨色、分段时间抖线、水彩颗粒和排线。
- STYLIZE 每像素只计算一次，写入独立颜色目标；SceneDof 保留源 32 样本景深，对已画好的描边颜色双线性采样。固定会议室的同笔触截图已逐像素一致（reload 17），但移动镜头、GPU 帧率及分层前景溢出仍需验收。
- ScenePost 使用 RGBA16F 场景目标、半分辨率高亮提取、四分之一及八分之一分辨率六遍 bloom、四遍手机 frost；最终阶段保留源 ACES/sRGB、调色、暗角、纸纹和 veil。所有中间 surface 显式 QueueUpdate。
- 便利店从已存在的冻结 game.data.Tuning.store 取值；第一章仍保留冻结调色中的 paper=false。没有将调色覆盖成 Git HEAD 默认。
- 默认管线连接便利店、第一章和回响。回响的实际 GPU 截图未完成。蓝白倒带的 present mask、标题到场景扫场、独立近景 RT 尚未接通，不把 shader 中存在公式等同于功能完成。

## 已运行的检查

- 205 项 ScenePost 生命周期/尺寸/模糊路由检查，包含 60 个 surface wrapper 先于父纹理回收；PASS。
- 536 项 NVG 场景交互检查；PASS。
- 标题原源码对照 10,240 帧；PASS。
- 冻结 11 层、2 份调色与时间轴 2,604 步对照；PASS。
- Lua 语法、LSP（0 errors）、git diff --check；PASS。

已实际读取的本地截图：

- validation/store/native-stylize-store.png：描边、纸纹、景深、辉光可见，无校验横幅。
- validation/store/native-stylize-phone.png：右侧背景虚化、手机文字保持清晰；真实剧情继续推进。
- validation/store/native-main-clean.png：main.lua 正常 Enter 进入；F2/F6/F8/F9 未触发调试功能。
- validation/chapter1/native-chapter-post.png、native-morning-post.png：独立开发入口核对两种场景；这些截图有开发文字，不代表正式入口，也不算通关。

两项 SurfaceShader 前端差异已等价改写并成功编译：标量列表 mat2 构造改为显式旋转；fragment 提前 return 改为 if/else。

## 本地退出与待复验修正

reload 19 在早晨场景回标题后退出，回响截图未得到。macOS crash 堆栈是 RenderSurface::Release → ~RenderSurface → tolua_collect_RenderSurface，EXC_BAD_ACCESS。读取已安装运行端的相关函数确认：getter 增加 surface 引用，Lua GC 减引用；析构时仍解引用父 Texture。

释放时原实现先 Dispose 父纹理，随后 Lua 才 GC surface wrapper。现已先解绑所有 viewport/sampler、清空 surface 引用、在纹理强引用仍存活时 GC，然后 Dispose 父纹理；同时移开仍指向即将销毁场景的主 viewport。模型回归通过，但**尚未本地复验该修正**，不能宣称崩溃已解决。

当前项目入口已恢复 main.lua。运行进程处于 failed / process_alive=false，未自动重启。官方 preview check 还存在既有 Cube/Day/DaySpecularHDR_QualityLow.dds 缺失错误，因此整体结果仍为 FAIL。

下一轮先复验资源释放、章节切换、重玩和缩放，再做动态多级 RT 延迟、性能与逐场景原版截图比较。完整报告：source-post-runtime-report.json、post-resource-lifetime-incident.json。本轮没有远端提交构建。
