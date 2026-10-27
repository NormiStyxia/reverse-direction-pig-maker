# 增量 04 恢复验收记录

本次接续既有未提交迁移，不重复提交 fe0453f，不改忽略规则或冻结包。

## 本轮完成

- 取得此前 preview start 的成功结果：session `00beca5b-7492-4906-b10f-bfb19d99745f`，PID 54219。
- 恢复编译 tests/native-window.swift、native-input.swift 到 /tmp，用已有 runtime 截图；没有另开 runtime。
- 实际读取 `validation/increment04/native/recovery-office.png`（实际内容为便利店聊天，并非办公区，文件名沿用采样计划）和 `recovery-phone-800.png`（800×360 内容区便利店）。这两张图不构成所有聊天/表情/转场验收。
- 原生日志记录回响 1–3 层 exitReached，进入第 4 层 levelPlayable；这些是运行日志观察，非本轮自动解谜输入回放，不能外推 19 层全通过。
- Application：手记/俯瞰共用加载、收尾、暂停门控，防止打断螺旋收尾。
- DormRenderer：H.drape 是材质 ID，按材质识别固定背景，避免误把节点 34 排除重组并让真正背景飞走。
- EchoHistory：雨节点定位使用实际原生子树索引，考虑实例化商品生成的额外子节点；保留真实末态与跨场景挂接。
- MechanismCard：短屏采用紧凑字号，按实际说明文字高度给图示分配剩余空间，预留关闭区。

## 检查

PASS：04 story/audio/mobile/cards/history，03 echo_post_lifecycle/scene_loading/cloud_save；217 个 Lua 文件语法通过（最后小批次后须再次检查）。
手记 64 种卡片/尺寸组合、90 个物理坐标点验、历史节点测试均为模型测试，不是 GPU/真机验收。

## 当前阻塞与未验

preview status/check：failed、process_alive=false；运行窗口随后已停止。尚无证据确定退出原因；启动第 0 帧原有 Cube/Day/DaySpecularHDR_QualityLow.dds 缺失仍然存在，不能据此断言它导致退出。
已按 AGENTS.md 提问是否重启，等待用户答复；不得自动复活停止的会话。
本轮新改动尚未 refresh/原生验证。螺旋完整收尾、宿舍重组、所有手机聊天表情、8 卡原生画面、19 层/全部分支/音频听感仍待验。
未进行本轮 Maker build/提交/推送，现有工作区修改全部保留。
