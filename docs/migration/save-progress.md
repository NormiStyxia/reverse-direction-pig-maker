# 存档与标题菜单（2026-10-16）

使用冻结 save.js 的 chapters 结构和浅合并语义。继续游戏只回到序章已到达的最深回响；第一章只记录回答，没有添加源版不存在的第一章检查点。首次到达更深层时保存 reached，六层结束保存 done，会议/办公区结束保存 answer。普通重玩保留进度；开发阶段跳关不更新玩家存档。

## 已验证

- SaveState 与冻结 save.js：14 次合并比较通过；7 个继续进度、49 个关卡锁定判断、5 种损坏/不可用存储回退通过。
- NativeSave 使用引擎 File/ReadString/WriteString 和 cjson，遵守项目与用户隔离。文件读写失败时保留本次会话内存进度。
- reload 29、30：独立测试文件写入 reached=4、done=true、answer=late，再用新的存档对象读回通过。玩家存档未修改。
- reload 29：F3 切换独立测试存档；标题“继续”实际进入第 4 层，关卡列表选择第 2 层实际进入第 2 层。第 5、6 层在 reached=4 时不可选。截图在 validation/chapter1/native-save-*.png。
- reload 30：第 1–6 层实时输入重放于第 6,452 帧通过，自动进入第一章。通过回调写入 reached=6，done=true；读磁盘确认，返回标题后所有六层已解锁，第 6 层标示“上次停在这里”。截图 validation/echo/native-six-route-complete.png，文件证据 validation/save/native-fixture-after-six.json。
- 标题静音切换已连接引擎主音量；游戏声音播放本身仍待实现，因此不能视为音频完成。

## 跨重启限制（未通过）

reload 29 → 30 → 31 每次刷新，独立测试文件都重新从 boots=0 开始。不能把同一进程内重新打开文件等同于跨重启持久化。

只读检查当前已安装 Maker CLI：Manifest 预览在 runtime-cache/127.0.0.1_<随机端口>/<资源散列>/savedata/0 下生成存档。refresh 会停止进程并调用 clearAssetCache，删除该端口的整个缓存目录；新进程使用新端口。实际存档文件确实在此目录中。因此当前官方本地预览环境不保留这类文件存档。未修改 CLI/引擎，未复制或伪造重启存档结果。

引擎本地文件指南另明确 WASM 文件系统刷新即丢失，Web 持久化应使用 clientCloud。当前本地预览没有云存档验收；最终目标平台的跨启动/刷新持久化仍需补充验证或官方存储接入。UI/触控完整验收与 95% 视觉验收均未完成。
