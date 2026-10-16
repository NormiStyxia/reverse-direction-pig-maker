# 尘团与纸片爆发迁移验收（2026-10-16）

基准仍为冻结 chapter1 `6a316e84907d8bc94ab59f20796685172b3535b5`，未修改 reference 源码或第一章调色。此项不是全游戏 95% 视觉验收。

## 实现

- `SpriteParticles.lua` 对应源版 spawnSprite、puff、burst、updateSprites；保留随机数调用顺序、寿命、位移、自转、最后四分之一寿命收缩及暂停行为。
- 序章、第一章、回响共用粒子池。推箱、刹停、合并、展开、货架倒下和实际倒带移动的生成位置与数量来自事件发生时的快照。
- `PuffRenderer.lua` 使用朝向实际相机的原生 CustomGeometry；双面不透明纸片以 alpha 0.4 镂空，写入主场景深度，参与描边、景深、光晕和闪白合成，不投影。
- 纹理由冻结 paintPuff/paintBurst 在独立 Chrome 导出，保留原 alpha；派生贴图在线性空间生成 mip。模型时间由玩法适配层推进，渲染同步不会重复推进时间。
- 测试入口独立保留于 scripts/preview；正式入口恢复 main.lua，玩家不能用调试功能键跳转测试。

## 已运行的检查

| 检查 | 结果 | 证据 |
|---|---|---|
| 源 JS 与 Lua 运动、缩放、寿命、随机序列 | PASS，5,060 帧 / 399,994 项标量检查 | sprite-particles-model-report.json |
| 全 11 层模型路线的尘团触发 | PASS，序章 6,477 帧 / 51 次，第一章 5,777 帧 / 68 次 | puff-route-events-report.json |
| 同尺寸原生/Three 颜色与镂空轮廓 | 2448×1376；有效区域 RGB MAE 0.486–0.671/255，覆盖 IoU 99.915%–99.978% | puff-rendering-report.json |
| 相机移动首帧与冻结 24 帧 | 0 像素变化 | 同上，sample 4/5 |
| 透明边缘的深度写入 | 深度覆盖 IoU 99.915%，内部误差 0；无矩形透明区深度 | 同上，sample 7 |
| 实际原生场景合成 | 已查看货架倒下、档案合并截图 | validation/puffs/play/ |
| 后处理资源生命周期和五种尺寸 | PASS，261 项 | scene-post-test-report.json |

画面对照使用相同原始尺寸，先将截图 ICC 转为 sRGB；误差排除共同背景，未缩放图像计算。上述 IoU 只衡量尘团局部覆盖，不代表整个画面的相似度。原生场景合成使用已对照的输入回放进入事件，但不是本次新增效果后的完整游戏通关。此前 effects-full-route-report.json 的完整原生通关早于尘团接入。

## 当前限制与后续

- 正式入口已恢复，当前本地 reload 47；标题、菜单和进入序章另留截图记录。
- Lua 全量检查仍有 27 条原有 ERROR，位于 PanelProbe、blue-check、EchoRenderer 和 PresentMask；尘团新增错误已清除，不能称项目零诊断。
- 官方 preview check 仍为 FAIL：缺少 Cube/Day/DaySpecularHDR_QualityLow.dds；本次运行未出现新增 Lua 或 shader 错误。
- 仍需补便利店蒸汽、原版程序音效、剩余分支/交互、跨重启存档和多分辨率实机验收；所有效果齐备后重跑完整路线并逐场景测量视觉差异。
