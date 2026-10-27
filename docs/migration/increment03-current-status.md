# 冻结增量 03 原生迁移验收记录

冻结基准：2026-10-27，源码树 SHA-256 `1e4ec744204da5269a0b9989fab42d91f1bd9703f12f94db4ad95d7603acefdf`。

**整体尚未验收。** 模型检查、原生路线、GPU 采样、图像对照和设备测试是不同证据；单项 PASS 不代表整个游戏达到 95% 视觉目标。

## 已实现与本轮修正

生产入口 `scripts/game/Application.lua`：原生 Lua 剧情/回响/回溯状态，真实 UrhoX 场景，raw NanoVG 界面。完整主线、三组分支、四组 6+5+4+4 层、九节点回溯、关卡模式、结尾重开已有实现。

- 回溯保留 world sun，增加独立 page sun；两个半球光线性叠加；移除本页不应显示的 world dust。源版实测见 `validation/increment03/timeline-live/source-light-state.json`。
- Post 生命周期：15 个源版节点状态、150 项参数匹配，见 `increment03-post-lifecycle-test.json`。
- 修复回响第 2 层后偶发丢失整个后处理：房间加载此前先更新 Renderer.loadId，外层检测不到换层，Post 留在已销毁的房间。现在 EchoProbe 在推进后统一销毁旧 Post、加载新房间并重建 Post；19 房间、同层重来及错误引用恢复模型检查通过，原生逐帧检查绑定到当前房间。
- 回溯 NVG 字距、键帽、标签留白/旋转、蓝色选层与触屏导航尺寸按冻结 CSS 修正。
- 裂纹材质按源 depthWrite=true 写入深度，新增 `StoreUnlitBlendDepth.shader`，导入器保留源标记。
- 纹理加载限制每帧请求数和并发数；测试覆盖同步/异步回调、取消和 mip 完成顺序。
- 角色图集无损拆为 28 帧，每帧 768px 原图配 128px 原像素 gutter；224 个 frame/mip 裁切一致。
- 植被和猪图集改用无压缩预制 DDS mip 链，原像素不缩放；18,432 个真实 GPU 采样通道逐字节一致。原始冻结素材保留。
- Web 端通过官方 clientCloud 持久化进度；桌面/移动原生继续使用项目/用户隔离 File。读档完成前暂停剧情入口，关卡模式仍可用；错误/超时退到当前会话并重试，成功读到远端后合并已解锁节点和最高过关层数。合并写入、失败重试和旧回调隔离通过模型检查；尚无真实云端刷新验证。
- 修复 20:9 会议/早上办公区交互提示报错：这些真实状态只有 phone 浏览面板，没有 browse 字段；此前合成测试给每个状态都添加 browse，漏掉了该错误。新增五种真实状态 × 两比例检查；保留既有 30 个冻结布局、1114 项坐标/触控检查。
- 8 个固定梦境/宿舍长音从冻结 StoreAudio.tone 原参数在独立 Chrome OfflineAudioContext 预渲染为 PCM16，最大量化误差 ≤0.5/32767；减掉播放当帧的长音合成，随机敲键等动态参数继续实时生成。见 increment03-fixed-tones-report.json。

没有修改原 H5 工作区、冻结包或 4173 服务，没有提交/推送/远端构建。新增 DDS 是原图的 mip 交付资源，不是天空占位贴图。

## 原生运行证据

| 范围 | Run ID | 结果 |
| --- | --- | --- |
| 旧快照 same/fix/sick 全主线 | b68a673e-d743-48b7-a883-8fb1c351bbe9 | 路线 PASS；0 Lua；性能 FAIL |
| 旧快照 late/wreck/pc 全主线 | 1b40e88b-0948-4645-a32b-381e1311c362 | 路线 PASS；0 Lua；性能 FAIL |
| 旧快照 done/leave/off 全主线 | c863ed45-a30c-478b-843a-fb2f6fdca90f | 路线 PASS；0 Lua；性能 FAIL |
| 19 层关卡模式与回溯 | a089689a-df84-4825-a0fc-662efc18c1a3 | 不写剧情、九节点/选层/返回/继续通过；性能 FAIL |
| 新 Post、回溯、UI 路线 | 5526ce45-7bb5-4ae4-9028-e99aaa156416 | 路线 PASS；0 Lua；3 尖峰，最大 430.533ms |
| 上述路线加角色拆帧 | fa326e8e-9395-404a-a211-64e787579d83 | 路线 PASS；0 Lua；2 尖峰，最大 371.421ms |
| 预制 mip 便利店静态/GPU 回读 | d165824b-6a52-4f72-bfa8-ad0616f5238a | 官方 PASS；0 Lua/0 超标尖峰；最大 90.454ms；18,432 通道一致 |
| 回响 Post 修复后的 19 层模式与九节点回溯 | 569fe023-087d-4cca-b582-1c472729f6d3 | 路线 PASS；0 Lua；3 尖峰，最大 156.899ms；官方 FAIL |
| 回响 Post 修复后的默认全主线 | 8b889552-075c-4662-9b59-9b6ed515da44 | 路线 PASS；0 Lua；39 尖峰，最大 1017.458ms；官方 FAIL |
| 20:9 late/wreck/pc 全主线，宽屏修复前 | 92dcb11f-80b4-4835-adf5-8999a475000c | 路线到结尾；3109 次 browse 空值绘制错误；不可验收 |
| 20:9 done/leave/off 全主线，宽屏修复后 | 7efb054f-e33c-49b4-afa2-e34750cc7c7c | 路线与结尾重开 PASS；0 Lua；15 尖峰，最大 165.578ms；运行帧预算未完成，官方 TIMEOUT |

最后一轮采用已有逐阶段性能计时，并且没有系统周期截图；与截图轮不是同条件性能 A/B，不能把数值下降全部算成代码收益。工具等待超时后均检查了后台进程和原始报告，未盲目重启。完整主线快照尚未包含最后的固定音 PCM 路由。

旧主线采用 2 倍模拟时钟、实际角色/机关控制，不是正常速度硬件输入测试，也不包含本轮全部渲染修正。三条组合覆盖每个分支值，不等于全部 27 个组合原生通关。UI 页和回溯测试中的全解锁 fixture 不作为自然解锁证明。

## 图像与限制

回溯 t=10s、同 seed/相机/Post、1280×720：早期全图 RGB SSIM 0.925413；深度修正阶段 0.932991、MAE 4.0038/255。指标采用 7×7 valid 窗口、sample covariance、RGB 通道均值，不是人工观感百分比，也不是全场景 95% 验收。图位于 `validation/increment03/timeline-aligned/`。

最终补图已完成并实际查看：16:9 run 882546f7-20c5-4e1c-ab5f-873f1800dccc，20:9 run 3a6c7e85-907a-42a8-9a20-850b3085bf5a，均包含最终手机按钮和选中标签层级修正。全图 SSIM 分别 **0.933484 / 0.948131**，MAE 分别 **3.8644 / 2.9492（0–255）**；仍不满足全场景 95% 验收。两轮均 0 Lua 错误，8 个固定 PCM 音频均观察到实际 SoundSource.playing 且未调用现场合成；官方各因一次 133.154 / 128.09ms 尖峰判为 FAIL。此固定时间视觉 fixture 刻意暂停场景，报告中的 scene_stalled 不作为玩法卡死证据。详见 increment03-timeline-final-visual-report.json。

截图位于 validation/increment03/timeline-aligned/timeline-final16c-client.png 和 timeline-final20c-client.png。官方截图回收持续 ENOENT，现有视觉证据来自实际原生窗口的系统截图；没有截图的轮次仅作为日志/状态/GPU 回读证据。

固定 PCM 验证只证明加载和播放状态，不证明扬声器听感/混音达到 1:1。运行阶段的合成大音延迟已从这 8 个固定音路径移除，整体性能仍未通过。

待验收：本轮修正后的主线/两比例、全场景与音频 A/B、真机手机与硬件多指、跨进程存档。当前 File 同进程重开通过，Maker 隔离验证清理存储，不能证明重新启动保留；Web 已接 clientCloud，但 mock 测试不证明真实服务保存与刷新恢复。云存档仍存在未完成回调即关闭页面、多个设备同时写入的限制，不能承诺这两种情况下最后一次修改一定保存。

第 0 帧天空资源错误尚未解决。官方 manifest 与平台缓存存在 `Cube/Day/DaySpecularHDR_QualityLow.dds`，用户 Lua 启动前的查找/加载时序尚待核实；未修改引擎或伪造替代文件。详见 `increment03-engine-sky-evidence.json`。Lua LSP 缺 `emmylua_check`，语法解析通过不等于完整 LSP 通过。
