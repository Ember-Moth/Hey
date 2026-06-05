# Hey UI 重构设计文档（iOS 极简方向）

> 制定日期：2026-06-05
> 关联：功能规划见 [`development-plan.md`](development-plan.md)；本文件只管 **界面与交互**，不涉及功能闭环。
> 原则：**简洁明了，又不丢信息**——信息靠层级和留白区分，而非堆叠卡片与装饰。

---

## 一、设计方向（已锁定）

经与作者对齐，确定如下基调：

| 维度 | 决策 | 备注 |
| --- | --- | --- |
| 视觉风格 | **iOS 极简** | 大留白、弱化阴影/描边、分组列表、大标题、少量强调色 |
| 配色 | **沿用现有暖橙主题** | 不重做色板，复用 `theme/Theme.ets` + `resources/{base,dark}/element/color.json` |
| 导航 | **底部 3-Tab，取代抽屉** | 连接 / 节点 / 设置 |
| 首要痛点 | ①导航藏太深（抽屉+溢出菜单） ②节点列表/操作 | 本次重点解决①，②部分解决 |

### 导航结构

```
┌──────────────────────────────────────────┐
│   ① 连接        ② 节点         ③ 设置        │  ← 底部 TabBar
│   ic_shield     ic_globe       ic_settings  │
└──────────────────────────────────────────┘
```

- **① 连接** — 只做"连不连"：大连接环 + 状态 + 当前节点选择行 + 流量/时长统计卡
- **② 节点** — 只做"选/管节点"：大标题 + 搜索 + 溢出操作菜单（可见）+ 订阅分组分段 + 节点列表
- **③ 设置** — 取代抽屉：iOS 分组列表，聚合所有配置入口，复用既有子页面

---

## 二、设计令牌（复用，勿硬编码）

代码里只引用语义令牌，不写十六进制。来源：`theme/Theme.ets`。

- **颜色**：`AppColor.brand / surface / surfaceAlt / textPrimary/Secondary/Tertiary / success / danger / divider / border …`（明暗自动适配）
- **间距**：`Space.xs(4) sm(8) md(12) lg(16) xl(20) xxl(24) xxxl(32)`
- **圆角**：`Radius.sm(8) md(12) lg(16) xl(20) pill`
- **字号**：`FontSz.caption(11) footnote(12) body(14) callout(15) headline(17) title(20) display(26)`
- **阴影**：`Elevation.card/raised/glow` + `AppColor.shadowCard/shadowBrand`

### iOS 化的取舍约定

- 卡片：圆角 `Radius.lg`，阴影尽量不用或极轻；用 `surface` 与 `bg` 的色差区分层级
- 列表：分组用 `surface` 块 + `Radius.lg`，行间 `0.5px` `divider` 细线，左侧留出图标缩进
- 标题：每个 Tab 顶部 `FontSz.display` 大标题
- 强调色 `brand` 只用于：选中态、连接态、当前项、主操作——不滥用
- **单一暖色强调**：全站不再使用蓝色系。原 `info` 蓝（资源页/分应用/对话框等）已统一为 `brand` 橙；左滑「详情/编辑」等次要操作用中性灰 `textSecondary` 与橙色「分享」区分；`success` 绿 / `danger` 红 作为语义状态色保留。`info`/`info_tint` 令牌现已闲置（保留备用）

---

## 三、各页面重构进度

> 状态：✅ 完成（iOS 重排+令牌化）· 🌓 仅深色令牌化（iOS 重排待做）· 🚧 进行中 · ⬜ 未开始 · ➖ 暂不动

| 页面 | 文件 | 状态 | 说明 |
| --- | --- | --- | --- |
| 应用骨架 / 底部 Tab | `pages/Index.ets` | ✅ | 抽屉→3-Tab，逻辑全保留 |
| 连接 Tab | `pages/Index.ets` | ✅ | 连接环 + 当前节点行 + 统计卡 |
| 节点 Tab | `pages/Index.ets` | ✅ | 标题/搜索/可见操作菜单/分组分段/列表 |
| 设置 Tab | `pages/Index.ets` | ✅ | iOS 分组列表，聚合 9 个入口 |
| 节点卡片 | `features/servers/ServerCard.ets` | ✅ | 精简为 国旗+名称+协议/地址+延迟+选中勾；操作改左滑 |
| 节点列表 | `pages/Index.ets` `NodeList` | ✅ | 升级为原生 `List`，行间细分割线，左滑「分享/详情/删除」 |
| 通用页头（全站） | `shell/PageHeader.ets` | ✅ | 改用令牌；细底分割线；统一带动 15 个子页页头 |
| 分组标签（共享） | `components/SectionHeader.ets` | ✅ | 品牌大标题→iOS 灰色小分组标签 |
| 设置行控件（共享） | `features/settings/SettingsControls.ets` | ✅ | 令牌化；隐藏开发者键名；语言改分段控件 |
| 设置偏好页 | `pages/Settings.ets` | ✅ | iOS 分组卡片；灰底+白卡+细分割线；品牌色保存按钮 |
| 订阅分组页 | `pages/Subscriptions.ets` | ✅ | 分组改 iOS 列表行（图标+名称+信息+开关/箭头）；操作改左滑 |
| 路由设置页 | `pages/Routing.ets` | 🌓 | 深色已适配；iOS 分组重排待做（下一个） |
| 分应用代理页 | `pages/PerApp.ets` | 🌓 | 深色已适配；iOS 重排待做（仍传旧键名） |
| 资源文件页 | `pages/Assets.ets` + `pages/assets/*` | 🌓 | 深色已适配（蓝/绿改 info/success + 新增 infoTint）；iOS 重排待做 |
| 日志页 | `pages/Logs.ets` `LogPanel`/`RuntimePanel` | 🌓 | 深色已适配；iOS 重排待做 |
| 扫码页 | `pages/Scanner.ets` | 🌓 | 深色已适配；系统扫码 UI 不重排 |
| 关于页 | `pages/About.ets` | 🌓 | 深色已适配；iOS 重排待做 |
| 节点详情/编辑 | `pages/NodeDetail.ets` `NodeEdit.ets` | 🌓 | 深色已适配；iOS 重排待做 |
| 导入/JSON/导出 | `pages/Import.ets` `JsonImport.ets` `Export.ets` | 🌓 | 深色已适配；iOS 重排待做 |
| 订阅详情/编辑 | `pages/SubscriptionDetail.ets` `SubscriptionEdit.ets` + 面板 | 🌓 | 深色已适配；iOS 重排待做 |

---

## 四、已完成详情（首页，2026-06-05）

### 改动文件
- `pages/Index.ets` — 视图层完全重构成 3-Tab；**所有 controller 逻辑（连接/选节点/测速/订阅更新/导出等）原样保留**
- `core/I18n.ets` — 新增 `tab.*`、`home.*`、`settings.group.*`、`settings.row.preferences`、`nodes.searchPlaceholder` 中英文文案
- 新增图标 `resources/base/media/ic_shield.svg`（连接）、`ic_globe.svg`（节点）
- 清理 5 个重构后失效的私有方法（heroSubText / bottomStatusText / localizeCoreMessage / deleteCurrentConfig / showRealConnectionTestUnavailable）

### 关键交互决策
- **溢出菜单解散**：原右上角 9 项菜单 → 节点 Tab 顶部可见菜单（更新订阅/测速/去重/清理无效/导出/服务重启/定位）；删掉了无实际作用的「删除配置」「真连接测速（仅提示不可用）」
- **当前节点行**点击 → `TabsController.changeIndex(1)` 跳到节点 Tab 选节点
- 程序化切 Tab 用 `TabsController`，高亮用 `@State currentTab` 驱动自定义 `tabBar` builder

---

## 五、待验证（本机无 DevEco/hvigor，未编译预览）

以上为人工逐行核对的代码，**尚未在 DevEco 编译或真机运行**。需重点验证：

- [x] 底部 Tab 点击高亮是否实时切换（自定义 `tabBar` builder 的状态响应）
- [ ] "当前节点"行点击能否跳到节点 Tab
- [ ] 节点 Tab 搜索框展开后宽度/边距正常
- [ ] 三个 Tab 大标题在真机状态栏下方是否被遮挡（当前沿用原内边距，未额外加安全区 inset）
- [ ] 深浅色模式下卡片/分割线层级是否清晰

---

## 六、下一步

1. 子页面逐页统一为 iOS 分组列表风格（下一个：路由页 `Routing.ets` → 分应用 `PerApp.ets` → 资源页 `Assets.ets`）
2. 安全区 inset 统一处理（若真机验证发现遮挡）
3. 待真机验证左滑操作手感后，决定删除是否加二次确认

### 左滑操作待验证项
- [ ] `ListItem.swipeAction` 在圆角裁剪的 `List` 上左滑显示是否正常
- [ ] 三个左滑按钮（分享/详情/删除）高度是否撑满行高
- [ ] 删除为即时生效（无二次确认），与旧版一致

---

## 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-06-05 | 建立文档；锁定 iOS 极简 + 3-Tab 方向；完成首页（连接/节点/设置 Tab）重构 |
| 2026-06-05 | 节点卡片精简为信息卡；节点列表升级为原生 `List`，操作改 iOS 左滑（分享/详情/删除） |
| 2026-06-05 | 统一通用页头 PageHeader（带动全站子页）；SectionHeader/设置行控件令牌化；设置偏好页改 iOS 分组卡片，隐藏开发者键名 |
| 2026-06-05 | 订阅分组页改 iOS 列表行 + 左滑操作（分享/编辑/删除），与节点列表交互一致 |
| 2026-06-05 | 真机修复三连：①Index 加 `onPageShow` 刷新（加订阅后节点列表实时更新）②PageHeader 覆盖层 `hitTestBehavior(Transparent)` 修复返回键被遮挡失效 ③节点搜索改为 header 内就地展开（搜索框+取消，带动画），不再在下方另开输入框 |
| 2026-06-05 | **子页面深色模式适配**：20 个子页面/组件的硬编码 hex 全量令牌化（~500 处），深色模式自动适配；新增 `infoTint` 令牌（base+dark）。已知保留的 3 处硬编码：①`nodeDelayColor()`/`delayColor` 的延迟状态色链（string 类型约束，中间调在深色下仍清晰）②`promptAction.Button` 系统弹窗色（BuiltinGeoCard） |
| 2026-06-05 | **配色统一为单一暖橙**：全站 `info`/`infoTint` 蓝 → `brand`/`brandTint` 橙；左滑次要操作改中性灰；延迟「测速中」蓝改橙。无蓝色残留 |
| 2026-06-05 | **App Logo 重设计**：保留「H+连接节点」图形语义，蓝色渐变 → 暖橙渐变 + 底部柔光波纹，青绿节点环改白色。SVG 源 `design/app-icon/hey-icon-{fg,bg,combined}.svg`，已渲染部署 foreground/background（AppScope + entry）与 startIcon(144) |
