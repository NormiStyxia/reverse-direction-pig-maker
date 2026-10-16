# 原版音效迁移（2026-10-16）

状态：第一批一次性音效已接入原生播放；源版资产和事件对照 PASS；本地 Runtime 听感、混音及设备播放尚未验证。音频迁移未完成。

## 基准与范围

冻结 main.js 默认 storeFlow 使用 StoreAudio；标题、序章、两组回响、第一章沿用同一个实例。MeetingAudio 是旧 c0 流程，未引入本次默认路线。

tests/audio-export.html 直接执行冻结 store-audio.js 的原方法，通过独立 Chrome OfflineAudioContext 导出波形。游戏只使用 UrhoX Sound/SoundSource 播放 WAV，不依赖浏览器。固定噪声 seed 6316 只用于生成可复核的雷声/滑门音参考。

本批 31 个片段：手机点击/发送/震动、停电、滑门、雷声、不同音量门铃、序章灯管与猪出现提示、第一章冻结与依次离场、推箱/刹停/倒架/合并、倒带有效/到头提示。资源位于 assets/audio/source；索引 AudioClips.lua。

## 接入

- AudioCues.lua 将剧情、物理事件映射为冻结音效。原 Chapter1State 的 leave 事件丢失了离场顺序对应的音高，现按源版 320-i*30 Hz 发出完整 tone 参数。
- EchoRun 保留跨关卡的倒带滴答计时，每 0.12 游戏秒按本次历史移动结果选 1500 或 900 Hz；重试补回源版 tap。没有修改碰撞、运动、谜题规则。
- AudioPlayback 持有独立 Scene，跨场景使用；每个片段独立 SoundSource，支持同时播放。Play(sound,0,1) 显式使用资源原采样率，WAV 已包含源版 master=0.9，避免叠乘音量或将倍率误作 Hz。
- 合并后的门铃按实际帧时间延迟 0.12 秒，对齐源版 setTimeout；切关取消旧 loadId 的未触发提示，已播放的片段继续自然结束。
- 异步加载完成前保留事件；重玩清空队列并停止当前声音，退出释放节点。PostUpdate 刷新播放队列，避免绘制频率或 hitstop 改变音频播放速度。
- 接入标题静音与游戏 M 键静音。生产 main.lua 入口不变，无新增玩家调试按钮。

## 已运行验证

| 验证 | 结果 |
|---|---|
| 冻结 WebAudio 到单声道 44100 Hz PCM16 | 31 段均无削波；每样本量化误差 ≤0.5/32767；audio-assets-report.json |
| 6 层序章回响即时声音 | 6,477 帧 / 105 次，源版与 Lua 逐帧一致 |
| 5 层第一章回响即时声音 | 5,777 帧 / 148 次，源版与 Lua 逐帧一致 |
| 延时/加载/切关/重玩/释放 API 合约 | 12 项 PASS；audio-playback-contract-report.json |
| 原有第一章模型、EchoRun 模型回归 | PASS；validation/audio/chapter-model.log、echo-run.log |
| Lua 语法 / diff | 10 个相关 Lua 文件编译通过，git diff --check 通过 |
| 全量 LSP | 27 条原有 ERROR，无本批新增 ERROR；validation/audio/lsp/ |

即时声音测试使用实际冻结 RewindLevels 方法；同帧声音并发混音，因此比较每帧参数多重集合，不宣称日志先后顺序一致。该 oracle 的 later() 是空实现，延迟门铃由单独合约测试覆盖。所有这些结果均不能代替 native 设备播放验证。

## 未完成项

- 房间底噪、冰柜嗡鸣/失谐、蝉与蟋蟀、雨与耳鸣，以及焦虑/门开/停电/折叠的连续增益变化。
- 办公室随机敲键 tone 的动态频率与幅度。当前显式计入 unhandledTones，未用变速固定短音冒充同包络。
- 序章门开事件的动态音量门铃/滑门触发；完整声音生命周期仍需对照。
- 实机的混音、异步资源、静音/M 键、切关重玩及听感回归。当前 preview status 为 stopped，遵守不自动复活窗口的约束，等待此前已提出的开窗确认。
- 蒸汽 GPU 对照、全分支/存档/多分辨率与逐场景 95% 视觉验收仍待完成。
