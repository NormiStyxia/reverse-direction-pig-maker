# 事件闪白与镜头震动 · 2026-10-16

本项补齐了已经由剧情/回响模型发出、但之前未被渲染端消费的视觉反馈。没有新增持续镜头抖动，未改变原版描边的 4 Hz 节奏。UI 保持 NVG，正式入口保持 main.lua；测试入口单独使用 preview/effects-check.lua。

## 来源与实现

ScreenEffects 对应冻结 main.js 的 hooks、updateCamera 和最终后处理参数。shock、flash、shake 按最大值合并；shock 更新随机种子。相机先按 .002^dt 衰减 shake，超过 .002 才在 X/Y 方向产生偏移，再朝原来的目标点 LookAt。后处理按 .02^dt 与 .0005^dt 衰减 shock / flash。镜头偏航也从震动后的真实位置计算，供下一帧使用。

序章与第一章直接消费原模型的 amount 事件。回响另将原实现对应的语义事件映射为：crateStop → shake .12，cabinetDown → shake .45，merge → flash .6 / shake .3，exitReached → flash .4。实际控制与自动路线均按 hitstop 后的游戏 dt 推进效果。后处理只读取值，不再按渲染帧重复衰减。

跨房间保留同一份效果状态，重新开始时重置。暂停/失焦时复用最后的相机偏移并停止衰减，不重新抽随机数。冻结 H5 第一章调色的 SHA-256 保持 1dae5f70540d5606ba113498d202bf45175721f817c8ef983669adf0ef8101a9。

## 已验证

- test_screen_effects.py 直接提取并执行冻结 JS 的 hooks、镜头偏移与衰减表达式：8,480 帧、51,309 项检查通过；含静止无偏移、事件形状及暂停稳定性。
- 原生 fixture：reload 40 / PID 53537，实际 2448×1376。idle、flash、shake、settled 四种状态的首帧与暂停后第 24 帧比较，全部 0 个不同像素。截图已读取。
- .6 闪白事件经过一帧后为 .5286084288；截图转 sRGB 后，与原始画面的源算法闪白混合比较，RGB MAE .3776/255，P99 误差 1.5134/255。该结果只测这一混合步骤，不能代表游戏相似度。
- 同时复核后处理资源生命周期 261 项、原版蓝白衔接 8,361 帧、描边/景深参数 5,029 项；序章 22,325 帧与第一章三种回答共 13,700 帧源码模型对照通过。
- 数据与图片：screen-effects-model-report.json、screen-effects-native-report.json、validation/effects/native/。所有图像指标按实际尺寸计算，没有缩放。

## 未完成的验收

当前管线下已重新完成一条完整原生路线：reload 41 / PID 54951，标题 → 便利店完整剧情 → 六层回响 → 会议/办公区（done 回答）→ 五层回响 → 09:58 → 第一章完。六层 6,452 帧、五层 5,692 帧真实输入逐帧校验通过，11 个出口按顺序通过；读取独立存档确认 reached=6、done=true、answer=done。全部阶段截图与原生日志在 validation/effects/full-route/，可执行验收报告为 effects-full-route-report.json。结尾截图已读取。本次通关包含消费者先注册的离屏渲染顺序、微尘、蓝白保色和新接入的事件效果。

这只覆盖一条路线与同进程存档读回。原版尘团/爆点、热食蒸汽、音频、逐场景对照、其他分支的原生通关、跨启动存档与完整触控适配仍待完成。此项不构成全游戏 95% 视觉验收。

官方 preview check 仍记录默认资源 Cube/Day/DaySpecularHDR_QualityLow.dds 缺失。静态检查不能使用启动时的空诊断报告作为通过证据；check 模式当前缺少 emmylua_check，已改用安装包内的 emmylua_ls 保持终端打开做完整扫描。

完整 LSP 扫描先发现 39 项诊断，其中本次新增检查脚本和 screenEffects 字段的类型标注问题已修正。最终仍有 27 项既有诊断，记录在 validation/effects/lsp-full/lua_errors.log；不能宣称全项目静态检查通过。58 个非大型数据 Lua 模块的语法检查与 git diff --check 通过。已停止本次 LSP watcher。

测试结束恢复正式 main.lua，官方本地刷新为 reload 42 / PID 62383。没有提交远端构建，也没有修改冻结 H5 源码。

正式入口再次从标题进入便利店，截图 validation/store/effects-production-store.png 已读取：NVG 手机入口/字幕与场景同时显示，没有调试横幅。validation/effects/production-check.json 仍仅记录上述默认 DDS 缺失，进程存活；不能将官方 FAIL 写成通过。
