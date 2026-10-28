# 手机 UI 缩放与 H5 标题适配（2026-10-28）

基准是 `reference/increment04/h5-source` 的冻结 H5，源码树 SHA-256 `936230c91fa6a133958ab44c7af44e864d1f720cf747cd150124a1a9f1453517`。冻结源码及原 H5 工作区未修改。

`render/UIViewport.lua` 统一标题、剧情、回响的 CSS 像素与触点换算。只在原生移动平台 DPR≤1、物理短边≥700 时，按短边/360 兜底（上限 4）。这是表现层估算，不能等同设备真实 DPR；有效 DPR 及桌面/Web 的比例保持原值。移动平台在首次触摸前就启用触控控件。

删除旧的 200px 方块菜单及全屏两列选关替代界面。`render/TitleCompact.lua` 按冻结 CSS 的响应式条件绘制 132px 菜单、44px 点击行、编号、英文、小猪指针；标题为菜单预留 148px。侧栏采用 min(65vw,360px)、44px 选项，19 层列表支持拖动、滚轮、键盘选项自动滚入及返回。普通桌面沿用设计坐标菜单。`Application.lua` 将滚轮派发给当前界面。

验证：

- `node tests/capture-ui-viewport.mjs`：独立 Google Chrome、隔离用户目录，直接读取冻结 HTML/CSS 和 DialogBox；1920×1080、1280×720、800×360、844×390、667×375 五组尺寸。指标和 PNG 在 `validation/ui-viewport/`。
- `python3 tests/test_ui_viewport.py`：144 组平台/分辨率/DPR；实际三套画布 resize；菜单物理坐标、多指归属、点击；五组 Chrome 菜单矩形、对白字号/头像直径；19 层可见、命中及 NVG 绘制路径通过。
- `test_increment04_mobile.py`：90 项物理触点检查通过。`test_increment04_cards.py`：64 份手记布局通过。8 个本轮 Lua 文件语法通过，`git diff --check` 通过。
- 旧 `test_title_nvg.py` 在旧菜单断言失败，旧 `test_story_nvg.py` 缺少新增表情按钮的 nvgCircle mock。将 HEAD 原版模块注入相同测试仍在相同位置失败，不能作为本轮回归通过项。

原生证据：`validation/UIViewportVisual.lua` 是隔离 UI fixture，模拟移动平台 DPR=1，使用真实 NVG/字体/资源；保留标题插画作背景，不代表实际剧情场景或主线通关。无图形验证运行 1200 帧，报告 PASS、断言 NOT_RUN，不能用来宣称 GPU 验收。截图模式两次均记录 `[Screenshot] captured`，但文件不存在，官方结果 FAIL；保留原始报告，不改写成 PASS。

最终截图运行 `19bd8b06-cd2b-416c-91d6-4f9b2581396d` 的日志未发现 Lua 错误，仍有既存 Cube/Day/DaySpecularHDR_QualityLow.dds 缺失。用系统截图按进程命令中的本工程 runtime-cache 路径识别窗口，实际读取 `native-frame-1.png`（标题）、`native-frame-3.png`（对白/触控）、`native-frame-5.png`（聊天），均在 `validation/ui-viewport/`。日志显示物理 2448×1104，模拟缺失 DPR 后有效比例 3.0667、CSS 798.26×360。对白/触控是合成状态，不能据此验收实际剧情中的避让。

较早 `unverified-native-*.png` 未核对窗口归属且为空黑图，不作验收。此处为较早的验证记录；后续正式预览与真实场景检查见下节。未提交、推送、远端构建或更新二维码。Android/iOS 真机与真实 Web 运行端仍需复验，不能声称全游戏像素级 1:1 已验收。


## 2026-10-28 本地 runtime 复查与浮动摇杆

按用户新增要求，移动端左侧空白区域按下呼出摇杆，松手隐藏；桌面鼠标布局不启用。盘面靠边时限位，但位移从真实按下点计算，避免初按就移动。保留 8 CSS px 死区、独立触点归属；第二根手指可以按倒带或动作键。暂停、失焦、尺寸变化、切场景及打开手机时清理移动状态，不恢复旧手指。聊天、物品面板和场景按钮保留输入优先权，禁用按钮区域也不用于呼出摇杆。

`PlayerControls.lua` 使用 `TouchControlSkin.lua` 绘制纸色主按钮、深色次按钮、表盘刻度与操作图形；按下会缩小/下沉并改变填色。主按钮 60–64 CSS px，次按钮 52–56，工具按钮 44。关闭手记的全屏命中区保持不可见。未更改引擎库，也未引入 Yoga UI。

结束页按冻结最终 CSS 修正宽屏 22px 标题、12px 副标题/按钮、44px 移动触点、直角细边框及纵向间距；五个 Chrome 视口的独立字体/矩形数据已比对。

真实原生窗口检查（隔离存档，测试入口模拟移动 DPR 回退；部分场景通过解锁节点直接进入，不能算自然通关）：

- `validation/ui-review/03-title-idle.png`、`04-title-844.png`、`05-options.png`、`06-levels-top.png`、`07-levels-last.png`：标题、设置、19 层列表。
- `14-dialog-visible.png`、`16-store.png`、`17-phone.png`、`18-stickers.png`、`19-stickers-scrolled.png`、`20-sticker-sent.png`、`21-timeline.png`、`23-look-card.png`：对白、便利店、聊天/表情滚动与点击、时间轴、物品卡。
- `31-controls-ready.png`、`32-floating-down.png`、`33-floating-drag.png`、`34-floating-release.png`：办公室新按钮及实际鼠标模拟按下/拖动/释放。中途系统焦点和剧情状态发生变化；截图只能证明该轮可见表现，精确初按零位移和多指由输入测试补充。
- `26-ending-after-ready.png`、`27-replay-click.png`：结束页尺寸调整和返回标题；这两张拍摄于最终直角边框调整前；本轮实际打开并核对 `29-ending-final.png`，最终直角细边框、标题和按钮均完整可见。
- `40-pause-confirm.png`：回响场景实际点击暂停，暂停面板和背景可见。
- `28-night-ready.png` 为加载状态，`35–39` 部分回响截图是黑底，均不作为画面通过证据。

跳层补建历史房间会调用 `active:activate()`，覆盖当前最终合成视口。`EchoHistory:fill` 现保留并恢复调用方视口；`test_echo_history_viewport.py` 修复前可复现覆盖，修复后验证分配、等待、捕获/销毁、完成四阶段均保留合成视口。此修复尚未补拍 GPU 对比图，不直接宣称此前所有黑底现象已解决。

无窗口回归：

- `test_floating_controls.py`：9 组视口/DPR，真实 Controls 模块的初按、死区、边缘、多指、六种状态门控、UI 转交和取消。
- `test_ui_viewport.py`：144 平台/尺寸/DPR、五组 Chrome 对白/结束页、标题菜单与 19 层命中。
- `test_increment04_mobile.py`：90 触点；`test_increment04_cards.py`：64 手记布局。
- `test_echo_history_viewport.py`、`test_increment04_history.py`、`test_increment03_echo_post_lifecycle.py`、`test_scene_post.py`：历史房间、19 层/重来、合成视口与 261 项后处理生命周期检查。以上为 Lua 模型/逻辑检查，不替代 GPU 画面。
- 正式 `main.lua` 已恢复，Maker `preview validate --mode validate --entry main.lua` 300 帧，报告 `PASS`、`test_result=NOT_RUN`（未请求 V helper 断言）。实际生命周期通过 Application 订阅 Update 驱动；静态标题树导致的 `scene_stalled` 不作为玩法通过证据。原始日志仍有既存 `Cube/Day/DaySpecularHDR_QualityLow.dds` 缺失及 `shader compile skipped (graphics headless)`，不能将报告摘要零错误解释为日志全绿。证据在 `validation/ui-review/headless-final/36810530-a63a-4024-bb41-113c787a07b4/`。

用户反馈聚焦干扰后，已停止交互窗口与 OS 输入操作，后续使用无头检查。项目缺少原始 `run-lua-validate` Skill，CLI 返回对应警告；本轮未升级工具、未改过滤配置。原生真机及尚未补拍的最终状态仍保留视觉复验边界。没有提交、推送、远端构建或更新二维码。


### 原生无头触摸与跳层复验

隔离入口 `scripts/validation/HeadlessTouchReview.lua` 通过真实 Application → Timeline → 回响第 6 层进入；仅使用隔离存档并在测试入口调用真实 TouchBegin/Move/End 处理函数，不发送 OS 鼠标/键盘事件，不设置桌面焦点。通过检查：

- 最终合成视口在补齐第 1–5 层历史房间后仍由当前 Post 持有。
- 初按零位移；拖动产生方向；第二指按倒带、释放倒带时不抢第一指。
- 经过 15 帧实际 `EchoRun` 更新，小猪坐标变化；松手立即清零并隐藏摇杆。
- 暂停清除触点，恢复后旧手指 move 不复活移动。

第一轮 `2027a6f7-2ee3-4141-a110-5aedfd398815` 为 FAIL：测试入口解锁存档后当帧激活了旧菜单快照，进入梦境，未到预期时间轴；保留失败记录。修正为下一帧使用 Application 更新后的存档快照后，复验 `ca172e02-271c-4bea-a225-948afb7dc943` 在第 1059 引擎帧输出 `HEADLESS_TOUCH_REVIEW_PASS`，运行 2850 帧，零 Lua 错误。

**总报告仍为 FAIL**：第 404/799 验证帧耗时 138.055/100.115ms，超过默认 100ms；没有调高阈值或覆盖失败报告。`test_result=NOT_RUN` 指没有运行引擎 V helper 脚本，以上是入口内普通 Lua assert 验证，有对应成功日志；不能称为官方 V 断言通过。原始证据在 `validation/ui-review/headless-touch/` 两个 run ID 子目录。未进行 GPU 图像复验或 Android/iOS 真机操作，黑底修复仅确认视口归属和运行路径。

最终正式入口与原 `main.lua` 相同；交互预览已停止，无头进程已完成并退出。没有后台窗口聚焦脚本、定时重启任务或远端发布。
