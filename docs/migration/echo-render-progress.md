# 原生序章回响接入（2026-10-16）

状态：六层便利店回响已接入原生网格、玩家移动/冲撞/倒带、动态货架/箱子/圆板/门、角色残影、跟随镜头和 NVG 基础 HUD。序章 finish 事件进入第一层；六层结束后已连接第一章会议室。**未达到视觉验收，不能报 95%。**

## 冻结基准与实现

仍为冻结 commit 6a316e84907d8bc94ab59f20796685172b3535b5；第一章未提交调色 SHA256 1dae5f70540d5606ba113498d202bf45175721f817c8ef983669adf0ef8101a9 保持不变。

- 构建时通过只读本地服务向冻结 rewind-levels.js 追加导出，直接执行原 buildLevel。没有更改冻结源码或来源仓库。独立 Chrome 仅用于导出；原生游戏不加载 Three.js、HTML 或截图。
- 六层共 749 源节点；完整节点、几何、产品实例、材质和 Canvas 贴图导出到 EchoScene1–6。贴图按内容寻址共享。具体数量/源哈希见 echo-1–6-export-report.json。
- 源入口区分两只猪：回响玩家是 pig-atlas-normi-round.png；便利店桌上反转猪仍是 pig-atlas-eight.png。没有混用。
- StoreRenderer 现在接受可选场景数据，保留默认便利店行为，复用已验证的坐标转换/模型共享/实例着色/继承显隐。EchoRenderer 负责回响专属动画与相机，不调用便利店剧情动态。
- EchoPose 直接移植 unfold/applyRoom 的枢轴变换、货架倒向/摇摆、门板/招牌/出口/圆板与倒带时钟。所有数据保留源右手坐标，渲染适配器只做一次 Z/四元数转换。
- 实际按键 WASD/方向键、J/Space 冲撞、K/Shift 倒带、R 重来进入已有 EchoRun，不直接修改谜题状态。失焦会清除待触发输入并暂停此调试场景。
- UI 使用 raw NVG 的逻辑像素模式；新增基础层名、操作提示和关卡 hint。源版完整字幕/死局提示、字距/阴影精调仍未完成。
- 序章 finish 后释放便利店场景并创建新回响，避免之前调试过的回响状态污染正式衔接。

## 验证证据

- 六层几何：PASS，636 个模型变体、30,492 个顶点与源逐项一致。
- 动画：执行冻结 JS 的 unfold/applyRoom，使用真实 Three 四元数/变换，与 Lua 对照 PASS，720 帧 / 18,960 项，误差 1e-9。此测试不验证 GPU。
- 连续解谜：test_prologue_echo_route.py 仅用移动、冲撞、倒带，PASS，6,477 帧输入解完六层，没有传送或 load 跳关。包括第 4 层货架复位后在关门延迟内通过、第 5/6 层金色箱子不倒带。
- 相同 6,477 帧输入再交给冻结 Pig.update / RewindLevels.update 及原始碰撞/时间线/切层方法：PASS，38,862 项状态检查，最终源版也进入 done。仅美术、声音、字幕、提示/死局提示及表现函数使用 stub；没有替换玩法算法。记录在 prologue-echo-source-route-report.json。
- 回归：回响 14 用例 / 5,755 步通过；便利店几何与继承显隐通过；Lua 语法通过；LSP 于 06:13:07 为 0 errors；git diff --check 通过。

本地 reload 21 / PID 21914：实际向 runtime 发送 K、D、W，日志记录第一层 exitReached → 第二层 loadLevel → levelPlayable；R 实际重开第二层。后续 F7 逐层加载第三至六层仅作诊断，不算通关。

本地 reload 22 / PID 31619：先用原有 F4 模型重放到便利店猪出现阶段，再恢复运行并实际按 F 触碰猪。06:14:12 出现 STORE_PROBE_DONE，随后 ECHO_FLOW loadLevel，06:14:15 第一层 levelPlayable。F10 记录位置 (-5.6,3.4)。这证明收尾衔接，不是从标题开始的完整剧情通关。

截图已查看：validation/echo/native-six-room-smoke.png、native-store-to-echo.png；第二层详图 validation/store/native-echo-level-two.png。官方 preview check 仍以 exit 1 报缺少 Cube/Day/DaySpecularHDR_QualityLow.dds（脚本运行之前的启动资源）；本轮实际日志没有新增 Lua / Shader 错误。完整证据见 local-echo-runtime-report.json。

## 仍未完成

- 天空、螺旋远景房间、浮岛、远猪、碎石与粒子尚未导入。六层雨 LineSegments 已在 reload 33 接入，见下方记录。
- 墨迹转场遮罩尚未实现，切层时仍可看到原始折叠/资源加载画面。倒带蓝白及“现在”对象排除、纸纹/描边/景深/调色/泛光等最终后处理未验收。
- 阴影与源版的差异仍存在。出口光柱已通过线性离屏合成对照；旧的直接输出 raw 图不适合判定生产版透明度，详见下方记录。不能用当前 raw 图宣布相似度。
- reload 30 已实时连续完成六层，6,452 帧输入后自然进入第一章。路线使用固定 camYaw=0 的源版验证输入，实际玩家在倒带镜头偏转下的全路线仍需验证。
- 第一章剧情/办公区/五层回响/09:58/结尾已接入，见 chapter1-route-progress.md；菜单与存档见 save-progress.md。声音/触控/分辨率适配与完整验收仍待完成。

## 本地开发入口

继续使用当前 live preview；修改后先查真实 status，只刷新仍存活的会话。入口 preview/title.lua：F9 直接进入回响诊断；回响中 F7 跳到下一层（不算解谜）、F6 暂停、F10 打印状态、F8 返回标题。正式路径是标题 Enter → 便利店剧情 → F 触碰猪 → 回响。

再导出：python3 tests/echo-reference-server.py；node tests/export-echo.mjs；python3 tests/import-echo.py。场景数据较大，使用仅绑定 127.0.0.1 的 POST 写入白名单 validation/echo/source-level-1–6.json，避免通过调试协议一次返回数百 MB。

## 2026-10-16 透明合成核对与雨线接入

已按纸感 skill 的顺序核查原始场景，未用后处理掩盖几何差异。发现旧的直接到 canvas 的 Three ACES 对照会先 tone map 再混合，而冻结游戏 post.js 先在 HalfFloat 线性目标混合，再执行 FINAL。这解释了同 opacity=0.2 时旧对照为 RGB 112/117/127、原生为 225/222/209 的差异。修正测试管线后，源版同点同样为 225/222/209；原生材质及透明度公式未改动。

新的 tests/echo-alpha-reference.html 从冻结 Post 取 FINAL 的 ACES/sRGB 段，以相同相机、t=5、0/源值/0.2/1 四档透明度分别采样。旧 direct 图保留作诊断，不作为生产版透明合成基准。该线性对照仍不包含世界背景、完整后处理、调色与 UI，不能代替最终画面验收；此前便利店/回响 raw 对照也须注意这种管线差异。

EchoRain 移植源 applyRoom 的 600 条雨线运动：正常每秒下落 12，倒带混合到向上 7，保留斜率、9 米循环及重生随机调用时机。六层种子从冻结 buildLevel 导出；更新只改变动态 CustomGeometry，不写谜题/玩家/存档状态。第一章回响保持源版无雨。原生更新使用 GetVertex/Commit，并在暂停时停止上传。

- 源码对照：6 层 × 240 帧，392,832 项检查 PASS；包含两方向越界重生、Float32 端点和种子不被修改，随机调用 15,022 次一致。
- 本地 reload 33 / PID 76401：六层均能加载，无新增 Lua/Shader 错误；第六层 F5 固定相机截图已阅读。F7 是诊断加载，不算本轮重新通关。
- 固定第六层的出口内部区域，平均通道误差 0.338/255，95 分位 1；天空内雨线掩码交并比 0.9663。均为局部特征指标，不是整图/整游戏相似度。
- 实际按 F6 恢复、K 倒带、释放 K，录制 40 张原始窗口帧与缩小 GIF。动态采样较低，不据此声称高帧率性能或全关视觉验收。
- Lua 73 文件语法 PASS；LSP 07:48:06 为 0 errors。官方 preview check 仍报启动资源缺失 Cube/Day/DaySpecularHDR_QualityLow.dds，因此不记录为全绿。

报告：echo-rain-test-report.json、echo-transparency-comparison.json、local-rain-runtime-report.json。
截图：validation/echo/native-rain-fixed.png、validation/transparency/regions.png。
动态：validation/echo/rain-motion/native-rain-motion.gif（缩小，仅看运动）。

回响诊断补充：F5 重建当前层的固定机位/时间夹具并暂停；F1 在该夹具内切换出口 alpha 0/0.2/1；F4/F6/F7 清除透明度覆盖，避免污染后续实际运行。固定夹具不会推进存档，不算通关。

## 2026-10-16 阴影补充

reload 37 已修复辅助镂空投影与落地偏移，猪投影局部 mask IoU 为 .9661，箱子为 .8952；未作为整图/整游戏相似度。24 场景材质分类通过，仍需处理只投影对象、receiveShadow 与完整后处理。详见 [阴影校准记录](shadow-progress.md)。
