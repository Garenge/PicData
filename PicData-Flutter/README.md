# pic_data

导航类 Flutter 客户端，用于展示 PicNet 配置生成的入口和图集内容。

## TODO

### 1. 图片并发下载数量 + 设置持久化（部分完成，后续可继续）

**已实现（当前代码）**

- 队列 B 最大并发改为**运行时配置**：`DownloadConcurrencySettingsService` + `SharedPreferences` 键 `pic_max_concurrent_image_downloads`；冷启动在 `main.dart` 里 `load()` 后再恢复下载队列。
- 「设置」→「最大同时下载图片张数」：整数输入，允许范围 **3–20**，默认 **3**；确定后持久化并调用 `PicDownloadModule.kickImageQueueAfterConcurrencyChange()`，**新上限立即参与调度**。
- 生效策略（当前口径）：**已在飞行中的单图下载不强行中断**；调高则立刻可多拉起待队列任务；调低则自然等待进行中任务结束后再按新上限补位。
- 相关文件：`lib/services/download_concurrency_settings_service.dart`、`lib/services/pic_download_module.dart`、`lib/pages/settings/settings_page.dart`。

**留给下次 / 产品可再定**

- 默认值与上下限是否改为可配置档位（如 3 / 6 / 10 / 20）或跟随网络类型。
- 是否需要「调低并发时**取消**部分排队中的单图任务」等更强策略（当前仅限制新开的 in-flight 上限）。
- 下载页或调试入口是否展示**当前生效的并发数**（便于对照设置）。
- 与站点限流、错误重试退避联动（避免高并发触发封禁时的自动降档）。

> 下载主体流程已可用；本节记录队列 B 并发相关已落地部分与后续扩展点。

### 2. 文件浏览器（`FileBrowserPage`，部分完成）

- **纯文本**：已实现——常见源码与文本扩展名（如 `.txt` / `.md` / `.json` / `.html` / `.csv` / `urls.txt` 等）点击后进入 UTF-8（容错）预览，超大文件截断提示（见 `text_file_preview_page.dart`）。
- **图片**：已实现——同目录下按自然序收集图片，`photo_view` 画廊左右滑 + 缩放（见 `local_image_gallery_page.dart`）。
- **PDF / Office 等**：文档预览（PDF/WebView 等）未做。
- **删除与下载记录联动**：已实现——本地删除文件/目录后，按下载记录中的本地目录同步清理持久化记录，避免残留下载状态。

### 3. 套图下载并发数可控（已实现，流水线后续可优化）

- **已实现（当前代码）**：「设置」→「最大同时下载套图数」，允许范围 **1–3**，默认 **1**；保存后持久化到 `SharedPreferences` 键 `pic_max_concurrent_set_downloads`。
- **生效策略（当前口径）**：调高后队列 A 立即补位启动更多套图；调低后不强行中断已开始套图，只限制后续新启动的套图数。
- **并发边界**：套图并发只控制队列 A 中同时进行的套图任务数；队列 B 的单图下载总并发仍由「最大同时下载图片张数」单独控制。
- **后续考虑**：当前单套任务仍是先 **整本分页解析完毕**，再 **整批入队队列 B** 拉图；若要进一步对齐 OC，可改为分页或批次产出 URL 后即投递队列 B，并同步设计 `urls.txt` 追加策略、进度文案、完成/失败判定与站点限流。

### 4. 重构图片预览功能（已实现，后续可继续打磨）

- **已实现（桌面）**：`LocalImageGalleryPage` 支持左右方向键切换上一张 / 下一张；系统长按方向键产生的重复按键会按固定节流间隔连续翻页。
- **已实现（桌面）**：支持 Enter 进入沉浸式全屏预览，Escape 优先退出本次预览触发的全屏状态；左右两侧提供上一张 / 下一张按钮。
- **已实现（手机端）**：手机端使用 `SwipeImageGallery`，支持横向翻页、缩放，并通过上滑或下滑关闭预览。
- **后续考虑**：继续细化缩放状态下的键盘翻页策略、触摸板手势阈值与不同桌面平台的全屏行为一致性。

### 5. 文件夹分享：压缩包与 PDF（部分完成）

- **已实现（当前代码）**：文件浏览器右上角分享入口支持对当前文件夹生成导出文件并拉起系统分享面板。
- **压缩包分享**：支持输入压缩包文件名与密码；默认密码为 **`8888`**，生成的 ZIP 需要密码读取文件内容。
- **PDF 分享**：支持将当前目录图片按自然顺序生成 PDF，并允许自定义 PDF 文件名；当前 PDF **未加密**。
- **后续考虑**：若要实现 PDF 打开密码，需要先确定稳定、许可证清晰、覆盖桌面与移动端的 PDF 加密方案，再接入默认密码 **`8888`**。

## 文档索引

- 首页列表右侧索引实现：`homepage_list_index_guide.md`
- 缩略图占位图与加载策略：`thumbnail_loading_strategy.md`
- 站点解析规则总览：`doc/parsing_rules.md`
- Flutter 抓取与解析实践笔记：`flutter_spider_notes.md`
- 文件网格自适应布局说明：`file_grid_adaptive_layout.md`
- 本地数据库设计：`lib/persistence/DATABASE_DESIGN.md`
- iOS 启动图资源说明：`ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
