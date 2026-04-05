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

### 2. 下载记录（TODO）

- 持久化「套图下载任务」与结果：例如任务状态、起止时间、`PicContent`/`PicHost` 关键字段、保存目录、成功/失败张数。
- 在「下载」 tab 或独立列表中展示历史记录，支持跳转文件目录、失败重试（可选）。
- 与现有 `PicDownloadModule` 队列衔接：任务入队/完成时写入或更新记录（SQLite / 现有 `pic_database` 演化，或独立表）。
- 记录生成时机（建议口径，便于实现对齐）：
  - 入队（队列 A）创建记录：`queued/started`
  - 分页解析开始后持续更新：`parsing_pages` / 已入队图片数量（可选）
  - 队列 B 图片下载完成后更新：`downloaded/failed/finished`

### 3. 图片并发下载数量 + 设置持久化（TODO）

- 队列 B（单图下载）当前有固定最大并发；需改为**可配置**，预设档位例如 **5 张**、**10 张**（或滑块/输入的具体数值，并设上下限）。
- 在「设置」页增加配置项，修改后立即作用于 `PicDownloadModule`（或统一从单例读取）。
- **本地持久化**：使用 `SharedPreferences`（与下载根路径一致）或项目内已有配置存储方式保存键值，冷启动恢复。
- 生效策略（建议口径，便于验收）：
  - 新入队的队列 A 任务：使用最新的并发配置；
  - 已在队列 B 运行中的任务：可选择「不中断，直到当前批次/整套完成」或「立即调整并发」（二选一，先实现简单策略）。

> 下载主体流程已可用；本节选为待补充的产品与工程细节。

### 4. 文件浏览器（`FileBrowserPage`，TODO）

- **图片**：点击进全屏/画廊预览（当前 SnackBar 占位）。
- **文档**：文档预览页（PDF/WebView 等，当前 SnackBar 占位）。
- **删除与下载记录联动**：本地删除文件/目录后，同步清理持久化的下载记录（与上文「### 2. 下载记录」衔接；`_deleteEntry` 内 TODO）。

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
