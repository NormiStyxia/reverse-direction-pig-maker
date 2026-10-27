# 反方向的猪 · Mivo 音频（2026-10-27）

四首纯音乐由 Mivo / Suno V5 生成，十二类音效由 Mivo / ElevenLabs Sound Effects v2 生成。原始任务、文件 ID 和完整提示词见 provenance.json；不包含访问密钥或任务 lease。

| 文件 | 用途 |
| --- | --- |
| music-dream.m4a | 蓝白梦境、会议室的时间错位感 |
| music-night.m4a | 深夜办公区、便利店 |
| music-puzzle.m4a | 四组解谜回响 |
| music-dawn.m4a | 清晨、宿舍和结尾 |
| impact.wav / slide.wav | 纸箱撞击、滑动及物件移动 |
| rewind.wav | 按住倒带的循环声 |
| mechanism.wav | 压板与门锁机构 |
| success.wav | 合成、出口与完成反馈 |
| transition.wav | 空间折叠、切换关卡 |
| tap.wav / notification.wav | 交互、手机消息 |
| paper.wav / pickup.wav / door.wav | 物件卡翻页、拿放物件、门锁轻响 |
| footstep.wav | 现实场景走动 |

音乐统一约 -20 LUFS、AAC 128 kbps / 44.1 kHz 立体声；短音效为单声道 PCM 16-bit / 44.1 kHz。轻交互 tap / paper / pickup / door 使用第二批 Mivo 素材，截为 0.25～0.45 秒、削去 1.8～2.4 kHz 以上的尖锐高频、峰值 -12 dBFS，首尾做短淡化；其余音效峰值 -4 dBFS。手机来消息保留 notification 双音提示，发送回执稍轻。

加载时处理音乐 1.8 秒首尾交叠、倒带 60 ms 接缝；切曲用 5.5 秒平滑等功率交叉淡化，旧曲逐渐收暗、新曲逐渐打开高频。首次播放淡入 3 秒，剧情静音淡出 1.2 秒。标题、回溯页、蓝白梦境共用 music-dream，来回切时保留同一个音源。混音留有余量，最终经过总线压缩器。原始生成素材也保存在 Cindy 本地媒体库，备用音乐版本未打入游戏。
