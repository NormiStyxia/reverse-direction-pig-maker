# 第一章剧情与 NVG 接入记录 — 2026-10-16

状态：**剧情模型通过；独立 NVG 面板可运行；尚未接入实际第一章场景，不是全流程或视觉验收。**

## 冻结版本

继续使用冻结 chapter1 commit 6a316e84907d8bc94ab59f20796685172b3535b5。导出前验证 ch1-scenes、meeting、ch1-office、ch1-tuning、Normi、Browse 源文件与 manifest 的 SHA256。实际调色配置仍为 SHA256 1dae5f70540d5606ba113498d202bf45175721f817c8ef983669adf0ef8101a9。基础参数合并冻结配置后 **paper=false**，未覆盖成 HEAD 默认。

## 本次实现

- scripts/game/Chapter1State.lua：会议和早晨两个原生 Lua 剧情模型；逆序定时器、角色运动/碰撞、表情恢复、手机/选择的消息延时、可选交互、三个回答和重复回答保护。
- 散会依次吊走同事、领导最后离场；小周消息与回复/回想；拿档案盒才能开门，门 k>0.7 才移除碰撞。
- 办公区可选道具、工位自动让位、小猪显现、冻结、时钟回拨一分钟、按答案更换全息盒、折叠结束返回答案。黄昏由位置单向推进；按源顺序更新时钟、景深强度、曝光/褪色/调色参数。模型保存原坐标，由渲染器转换 Z。
- 早晨时钟从14:47倒转至09:58；检查空盒或14秒超时触发三种领导消息；8.6秒后完成第一章。
- Chapter1Panels 把本章 BrowseOverlay 状态接到已有 raw NVG StoryOverlay。没有 Yoga/UI 库。
- Chapter1Fixtures 增加10个真实模型生成的独立面板状态。PanelFixtures 总数16，F7循环；本地渲染入口增加 Chapter1Smoke。

模型输出到原生场景仍需接线：人物表情图集、依次离场的 flat 变换、门板偏移、投影标题贴图、档案盒显隐和全息答案材质、小猪旋转/放大、整层楼绕 pivot 折叠、镜头、时钟、灯光/雾/天空与后处理。cam() 给源镜头请求，fx.focus 距离需由实际相机位置供给，折叠 veil 中心需投影 pivot。faceFrame() 给表情图集格号。音效、字幕和粒子当前为事件，未播放/投影到第一章场景。

## 验证

1. node tests/export-ch1.mjs — 源哈希校验，导出对话、3个会议障碍、7个办公区障碍、人物/工位/门元数据与调色。
2. python3 tests/test_chapter1.py — **PASS：13,700帧，2,750,396项状态检查，11场景，9次模型完成**。直接执行冻结 Ch1Meeting/Ch1Morning/Normi/BrowseOverlay，与Lua同输入逐帧对照。使用真实THREE物体/场景构建；画布绘制、装饰素材、音频为惰性适配。覆盖3回答、2种早晨触发、门控、可选道具、重复提交、逆序定时器、变帧率、seed随机调用次序、FX数值。测试设置位置以隔离交互，**不等于玩家纯输入通关**。
3. 本地 UrhoX VM：**CHAPTER1_MODEL_SMOKE: PASS; 4778 frames; 6 model completions; same/late/done; paper=false; visuals not tested**。原有序章3060帧本地冒烟也通过。
4. python3 tests/export-panel-fixtures.py + node tests/capture-panels.mjs — 独立 Chrome，16份冻结 DOM 截图/布局数据。复用已有本地8776服务（PID51282），未连接私人浏览器。
5. python3 tests/test_story_nvg.py — **PASS：序章42次 + 第一章70次渲染/输入检查，7种尺寸/DPR，300项源浏览器布局对照**。实际NVG选择区域回调正确接到第一章答案；必选面板的关闭操作不会越过剧情。只有1920×1080布局有DOM对照，其余为模型适配测试。
6. python3 tests/test_prologue.py — 原有22,325帧差分回归通过。
7. **45个Lua文件语法通过，LSP 0 Errors，git diff --check通过。**

## 本地 runtime 与截图

- 正式CLI自动refresh，session fa6bf3f4-f069-471e-b264-2c39c9194da0，**reload23，PID55617**，入口 preview/title.lua。
- 本次实际截取并检查：三个回答面板、已做完回答、小周回复/回想、早晨done消息。全部为独立NVG面板，不是会议/办公区场景。
- validation/chapter1/native-question.png 对照 validation/panels/h5-fixture-8.png；其他文件为 native-done-answer / native-zhou-recall / native-morning-done。
- python3 tests/compare-chapter1-panels.py 记录4组头部/内容/按钮区原始RGB误差和三列图，不用大面积空背景计算相似度。结果在 chapter1-panel-comparison.json。
- 仍可见**字重/基线与头像缩小采样差异**，未做整体95%声明。场景磨砂压虚未验收。
- 官方preview check仍为FAIL：启动缺 Cube/Day/DaySpecularHDR_QualityLow.dds。当前日志未出现新增Lua错误；这不能改写官方FAIL。
- 结束时runtime停在**面板16（早晨done消息）**，冻结fixture，PanelDemo.active=true/live=false。F8回标题，F7回面板1。不要误当成真实剧情已走到结尾。

## 后续顺序

导出冻结 Ch1Meeting/Ch1Morning 实际场景（浏览器真实纹理，不使用模型测试中的空画布），以已有通用 mesh serializer/importer 和 StoreRenderer(data) 接入。接6层序章回响完成→会议/办公区→5层会议回响→早晨→章节结束，再做完整原生玩家输入通关、全部分支/存档菜单/适配和逐场景视觉对照。世界布景、阴影、蓝扫场、墨幕、景深/纸纹、粒子、音频及退出光柱透明度仍需完成。
