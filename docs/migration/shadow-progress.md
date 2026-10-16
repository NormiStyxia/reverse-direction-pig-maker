# 原生阴影校准（2026-10-16）

尚未通过全游戏视觉验收。当前工作只校准原始场景阴影，不用后处理掩盖偏差。

## 已定位并修正

1. 全局阴影原本已开启；关掉阴影会改变货架和后墙，但旧偏移 .0008/.5/.03 擦掉了猪和箱子的落地阴影。清零后恢复落地阴影，却导致表面条纹。逐项试验后采用常数 .00005、坡度 0、法线偏移 0。它是本机原生参数，不把 Three 的负 bias 直接抄过来。
2. 原有 fragment discard 加空 vertex 并未让此版本 runtime 的辅助阴影正确镂空。补充 ALPHA 与 ALPHA_SCISSOR_THRESHOLD 后，日志显示真正的 SURFACE_SHADOW_ONLY 和 SURFACE_DEPTH_ONLY 材质程序，猪投影从整片矩形变为轮廓。材质保持不透明深度，没有添加 blend_mix 或 depth_draw_never。
3. 导入器统一选择 Lit/Unlit Cutout；重新导入 24 个冻结场景。1433 个材质中 124 个 cutout、851 个 opaque、384 个 blend、74 个 add。冻结 alphaTest、opacity 逐项一致。

## 实际对照

源版 tests/capture-echo-alpha.mjs production 已应用 world.js 的 2048 阴影图、±11 边界、near 1/far 40、bias -.0008/normalBias .03。使用线性 HalfFloat 合成后 ACES/sRGB，仍未包含完整 FINAL 后处理、世界与 UI。旧 direct 图不能作为透明合成验收基准。

本地 reload 37 / PID 5621：第六层 t=5 固定机位及便利店固定帧已截图并阅读。植物投影镂空可见。日志无 Lua/Shader 编译错误；官方 check 仍 FAIL，原因是启动前 Cube/Day/DaySpecularHDR_QualityLow.dds 缺失。

猪投影 floor-only 区域 [1040,613,1140,650]，mask IoU 从零偏移矩形阴影的 .3341 提升至 .9661，平均通道误差从 27.142 降到 2.025/255。箱子区域 IoU .8952，仍有边缘差异，不取平均掩盖。该局部指标绝非整场景或整游戏相似度。

测试：材质分类 PASS（24 场景/1433 材质）；便利店几何 37632 顶点、回响6几何5976顶点对照 PASS；Lua73文件语法 PASS；LSP 08:07:44 为0错误。此次未重跑完整通关，F7/F5是诊断入口。

## 尚未完成

- 便利店 roof/leaf 的只投影不写颜色对象仍使用 viewMask=2，实际阴影不完整。IN_SHADOW_PASS 曾被安装版拒绝，不能以修改引擎或 Technique 绕过。
- 源节点 receiveShadow=false 尚未迁移；可调查正式 surface render_mode shadows_disabled，并按节点拆分共享材质，须实测。
- 箱子轮廓边缘、其它层/第一章及运动机位需要进一步对照。
- 完整源版后处理、世界背景、音效、触控、多分辨率、存档跨刷新及剩余分支验收仍待完成。

证据：local-shadow-runtime-report.json、echo-shadow-comparison.json、scene-material-test-report.json。
截图：validation/echo/native-shadow-final.png、validation/store/native-store-shadow-final.png、validation/shadows/pig-shadow-detail.png（依次源版、矩形旧投影、零偏移镂空、小偏移镂空）。

诊断：Store/Echo 中 F2 切全局阴影，F3 循环原参数/去法线偏移/零偏移/大常数/小常数，F11 切 focus。启动默认小常数；F5 固定帧不修改存档。F2在标题仍是完整路线测试。不要将诊断开关状态用于正式验收。

## 2026-10-16 阴影接收标记（reload 40）

已迁移所有冻结场景的逐物体 receiveShadow。源材质有共享：同一门框材质同时用于接收/不接收阴影的网格，不能只修改一份全局材质。导入器对全部不接收者设置 receive_shadow=0，混用者生成独立 no-receive XML；实例材质缓存键包含接收标记。原始 castShadow、alphaTest、opacity 均保留。第一章动态换材质也经同一选择方法。

安装版 runtime 的 shadows_disabled 在 custom light 中不生效：reload38 前后便利店/回响图逐像素相同；reload39 强制地板 noReceive，SetSurfaceShader 返回 true，地板阴影采样未变化。仅一像素噪声，不能将“接受语法”当成功。该实验 shader 已移除，证据截图仍保留。

最终方案使用 SurfaceShader 的 receive_shadow 参数，方向光贡献乘 mix(1, ATTENUATION, receive_shadow)。这是场景专用的源版等价实现：唯一开启的原生灯是方向光，其距离衰减为1；源点光的距离/截止衰减已在 fragment 中独立计算，原生点光组件保持禁用。没有修改引擎、生成 Technique 或源仓库。未来增加原生点光时必须重新评估该约束。

实测 reload40：F5固定第六层，F12临时只切地板接收；投影像素 [1070,627] 从 RGB14/24/34 变成58/83/104，变化12971像素，墙面/天空不变；再次F12恢复后与原图逐像素一致。已经恢复原接收设置，再截图便利店和第一章会议室，三幅图已阅读，未出现Lua/Shader错误。官方check仍因 Cube/Day/DaySpecularHDR_QualityLow.dds 缺失而FAIL。

验证：24场景、1433材质、3020逐节点实际Lua材质选择PASS；显隐5733节点/15197绘制对象检查PASS；动态720帧70560项源版对照PASS；Lua73文件语法与LSP0错误。冻结ch1-tuning SHA256仍是1dae5f70540d5606ba113498d202bf45175721f817c8ef983669adf0ef8101a9。

报告 local-shadow-receiver-runtime-report.json 与 shadow-receiver-comparison.json。F12仅在回响F5诊断夹具中有效，修改的是克隆地板材质，不影响谜题/存档；重建关卡会清除诊断覆盖。此轮没有重跑通关或宣称95%。roof/leaf只投影对象、完整后处理、其它分支、触控/分辨率/存档仍待完成。

## 2026-10-16 屋顶/树叶只投影与PCF剔除（reload44）

StoreShadowOnly.shader 已替换屋顶材质10和树叶材质27，移除旧viewMask=2隐藏方案。使用正常空间材质以取得投影通道，显式ALPHA/ALPHA_SCISSOR保留透明轮廓；通过 PROJECTION_MATRIX[3][3] 区分当前游戏的透视画面与方向光正交投影，在透视颜色和深度pass中discard。实测无光照版本未生成投影pass；改用空间光照材质后日志出现SURFACE_SHADOW_ONLY，屋顶遮光可见且屋顶未显示。未改引擎、底层Technique、冻结源码或相机几何。该方法只适用于当前透视相机+方向光阴影；增加正交游戏相机/聚光阴影时需另行适配。

树叶仍缺投影的原因是shadowcull映射。冻结Three WebGLShadowMap使用FrontSide→BackSide、BackSide→FrontSide、DoubleSide→DoubleSide；此前导入固定ccw，剔除了从背面受光的叶片。现在按原规则生成shadowcull，24场景已重导入。树叶光斑恢复到墙面、桌椅和地面。主画面cull与源几何未变。

### 对照基准补充（重要）

StoreChapter构造器在world.js基础上覆盖bias=-.003、normalBias=.08、radius=1.4；dispose没有恢复这些值。因此正常标题→便利店→六层回响会继承这组值，?chapter=echo调试直达则保留world.js的-.0008/.03。此前echo-shadow-comparison.json的.9661猪投影局部IoU对应调试直达，不能作为正常流程的结果。已保留历史数据并标注入口；新增tests/capture-echo-alpha.mjs story与echo-shadow-story-comparison.json。正常流程参考下当前猪投影IoU .8499、箱子 .8351，尚未通过视觉验收。

便利店的新对照以冻结场景、StoreChapter实际阴影参数、线性HalfFloat后原版FINAL的ACES/sRGB输出四组：none/roof/leaves/both。tests/export-store.mjs --shadows-only只写验证图片，不覆盖冻结源码或source-scene.json。完整后处理仍不在该对照中。

### 当前实际结果

reload44/PID42887，实际窗口1920×1080。F5固定便利店后F12分别切none/roof/leaves/both；恢复后与初始both逐像素相同。五组截图、折叠阶段及第六层已阅读。折叠使用真实模型重放诊断，不算一次通关。

- 右侧墙屋顶贡献mask IoU .9897，最终像素MAE1.028/255。
- 树叶左后墙贡献mask IoU .5352，最终MAE2.655/255；地板贡献IoU .2589、MAE33.987/255，边界和柔度仍明显不符。
- 左侧墙屋顶贡献IoU0、MAE15.269/255，仍存在明显漏光区域。不计算平均值掩盖它。
- 24场景1433材质/3020节点选择及PCF剔除检查PASS；720帧70560项动态对照PASS；Lua73文件语法PASS，LSP08:33:01为0错误。早先诊断模式数组类型注解引起1条LSP错误，已修正并于reload44验证。
- 官方check依旧因启动资源Cube/Day/DaySpecularHDR_QualityLow.dds缺失FAIL；当前Lua与Shader无新增错误。

报告：local-shadow-caster-runtime-report.json、store-shadow-comparison.json、echo-shadow-story-comparison.json；局部对比图validation/store/shadow-regions.png。下一步仍需校准方向光投影覆盖、偏移/柔度及源外景着色，再完成后处理和其余全游戏功能验收。

## 2026-10-16 夜景地面、Sprite 导入及阴影校准

受光地面原先没有执行源 night.js；StoreLit 现按原公式变换 base/emission 和方向光的各项贡献。该变换对颜色是线性的，分项相加等价于源版的光照后处理，室内 night_kind=0 保持不变。源版两处窗外道路 MAE 从64.914/67.162降低到2.773/3.701（255通道尺度）；两处室内控制区域逐像素未变。证据 store-night-comparison.json、validation/store/native-night-baseline.png；不是完整游戏分数。

四个路灯光晕已加入原生相机朝向 quad，沿用源材质和层级显隐。首次截图发现形状错位，定位为源 Sprite 的 InterleavedBufferAttribute：旧导出直接取 array，把 position/uv 的共享 stride5 数组当作紧密排列。已修正两个导出器，通过 Three getX/getY/getZ/getW 读取；--sprite-geometry-only 重新执行冻结源码，只允许 Sprite 几何变化，实际只有 geometry55。其它源场景字段保持不变。重新导入并通过37638顶点（包含Sprite）及属性分量数检查。修正后的quad尚未GPU复验；reload4的光晕截图是修正前，不能作验收。源人物/贴图/模型没有重新生成。

阴影诊断覆盖focus/autoSize/nonUniform、softness0、1024/2048/4096、正负常数偏移、native normalOffset。负常数-.0002可遮住左墙漏光，却使后墙/桌面全暗；native normalOffset .03/.08同样破坏其它面。4096更锐利但叶片地板MAE反而从33.989升到36.935，因此没有采用。所有默认参数仍为bias .00005/0/0、map2048及原focus。完整区域记录shadow-calibration-report.json，不以平均掩盖失败。源版关闭阴影/清零bias与normalBias对照已保存；LIGHT_VERTEX被当前runtime明确拒绝，试验已移除，失败截图单独标为INVALID。

本地旧会话reload45因公共索引下载失败退出，经官方重试恢复session82c1a14d；reload1/3/4无新Lua/Shader错误，官方check仍因Cube/Day/DaySpecularHDR_QualityLow.dds缺失FAIL。reload4已观察夜景、折叠、回响6，回响与旧参考最大通道变化3/255，未重跑完整通关。随后状态stopped；用户明确同意重开，官方start又因Public source index download failed而未启动。新session1d16f694当前failed，不能声称修正后的Sprite已运行。

离线检查：24场景1433材质3020接收标记PASS；显隐19次切换8379节点22306绘制对象PASS（含Sprite及根节点隐藏）；73Lua语法PASS、LSP0错误。冻结ch1-tuning SHA256仍为1dae5f70540d5606ba113498d202bf45175721f817c8ef983669adf0ef8101a9。

用户于2026-10-16明确要求提交远端构建一次并自行拉取；此次按Maker官方插件执行，属于开发验收包。全流程剩余分支、阴影/完整后处理、音效、触控、适配和跨刷新持久化验收仍待完成。
