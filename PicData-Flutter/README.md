# pic_data

导航类 Flutter 客户端，用于展示 PicNet 配置生成的入口和图集内容。

## TODO

### 1. 网络代理支持（计划中）

- 在应用设置页中提供「自定义 HTTP 代理」配置（例如 `host:port`、是否启用）。
- 在 `NetClient` 中统一接入代理逻辑：
  - 优先使用用户在应用内配置的代理；
  - 若应用内未配置，尝试自动检测当前系统/设备的代理设置；
  - 如未检测到任何代理且为桌面端（macOS/Windows）调试环境，可回退到本机默认代理（例如 `127.0.0.1:7897`）。
- 为不同平台预留扩展点：
  - 桌面端：通过环境变量或平台特定 API 读取系统代理；
  - 移动端：预留原生渠道（MethodChannel）查询系统 Wi‑Fi/蜂窝网络代理。

> 上述功能目前尚未实现，仅作为后续演进方向的设计记录。

### 2. 调试角标替换为自定义透明浮层（计划中）

- 背景：当前 Debug 模式右上角默认 `DEBUG` 标记遮挡页面交互区域，影响按钮可见性和调试体验。
- 目标：
  - 移除 Flutter 默认右上角调试角标；
  - 使用自定义 `Dev` 浮层替代，并保持半透明，尽量不遮挡页面内容。
- 验收标准：
  - Debug 模式不再显示系统默认 `DEBUG` 标记；
  - 自定义浮层显示在右上角（或可配置位置），文字清晰可识别；
  - 浮层具备透明度（例如 `opacity 0.25~0.45`），能看见下方按钮；
  - 浮层不拦截点击（`IgnorePointer`），不影响页面交互；
  - Release 模式默认不显示该浮层。
- 建议实现方向：
  - 在 `MaterialApp` 关闭默认调试角标（`debugShowCheckedModeBanner: false`）；
  - 在应用根层通过 `Stack + Positioned + IgnorePointer` 添加自定义 `Dev` 视图；
  - 将开关与样式参数（显示开关、透明度、位置）集中管理，方便后续调整。

### 3. import 路径规范整理（计划中）

- 背景：当前存在较多 `../../` 相对路径 import，可读性一般，跨目录移动文件时维护成本较高。
- 目标：统一为更稳定的工程根路径风格（如 `package:pic_data/...`）或项目约定别名，减少层级相对路径。
- 验收标准：
  - 新增代码默认使用统一 import 风格；
  - 现有核心页面与服务模块完成一次批量整理；
  - `dart analyze` 无新增 import 相关警告；
  - 团队文档中明确 import 规范与示例。

## 文档索引

- 首页列表右侧索引实现：`homepage_list_index_guide.md`
- 缩略图占位图与加载策略：`thumbnail_loading_strategy.md`
- 站点解析规则总览：`doc/parsing_rules.md`
- Flutter 抓取与解析实践笔记：`flutter_spider_notes.md`
- 文件网格自适应布局说明：`file_grid_adaptive_layout.md`
- 本地数据库设计：`lib/persistence/DATABASE_DESIGN.md`
- iOS 启动图资源说明：`ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`

## 页面导航栏点击日志（PageBackdoor）

- 触发时机：用户点击页面 `AppBar.title` 时触发。
- 打印格式：`[PageBackdoor] class=<ClassName> file=<FilePath>`。
- 生效环境：仅 Debug 模式生效（`kDebugMode == true`），Release 不打印。
- 公共方法：`lib/debug/page_backdoor.dart` 中的 `debugPrintPageBackdoorInfo(...)`。
- 新页面约定：所有新建页面都在导航栏标题加 `GestureDetector`，点击时调用该方法。

示例（可直接复用）：

```dart
AppBar(
  title: GestureDetector(
    onTap: () => debugPrintPageBackdoorInfo(
      className: 'SettingsPage',
      filePath: 'PicData-Flutter/lib/pages/settings/settings_page.dart',
    ),
    child: const Text('设置'),
  ),
)
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
