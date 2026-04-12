# pic_data

导航类 Flutter 客户端，用于展示 PicNet 配置生成的入口和图集内容。

## TODO

### 1. 图片并发下载数量 + 设置持久化（部分完成，后续可继续）

**已实现（当前代码）**

- 队列 B 最大并发改为**运行时配置**：`DownloadConcurrencySettingsService` + `SharedPreferences` 键 `pic_max_concurrent_image_downloads`；冷启动在 `main.dart` 里 `load()` 后再恢复下载队列。
- 「设置」→「最大同时下载张数」：整数输入，允许范围 **3–20**，默认 **3**；确定后持久化并调用 `PicDownloadModule.kickImageQueueAfterConcurrencyChange()`，**新上限立即参与调度**。
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
- **删除与下载记录联动**：本地删除文件/目录后，同步清理持久化的下载记录（`_deleteEntry` 内 TODO）。

### 3. 解析与下载流水线对齐 OC（TODO）

- **现状（Flutter `PicDownloadModule`）**：单套任务先 **整本分页解析完毕**，再 **整批入队队列 B** 拉图；队列 A 在 `_pumpSetQueue` 里对多套任务是 **串行** 的（一次只 `await` 处理一套，当前没有「同时解析多套图」的配置项）。
- **OC 项目**：**边解析边下载**（解析过程中持续往下载侧投递）；并有「同时进行中的解析任务数」等调度上限（可参考仓库内 `flutter_spider_notes.md` 里 `ContentParserManager` / `ParseOperation` 相关笔记）。
- **后续考虑**：是否改为分页或批次产出 URL 后即投递队列 B；与 `urls.txt` 追加策略、下载记录进度文案、完成/失败判定口径一并设计。若支持多套并行解析，需单独设计 **最大并行套数** 与资源（网络、磁盘、站点限流）之间的平衡（与下文「### 5」衔接）。

### 4. 队列 A 多套图并发上限（TODO）

- **现状**：`_pumpSetQueue` 串行，同一时间只处理 **1 套** 套图任务。
- **后期考虑**：支持 **最多同时 3 套图并发**（解析/拉图流水线在架构上允许多套并行时的上限）；需与队列 B 单图并发（见「### 1」）、站点限流与下载记录状态展示一并设计。

### 5. 重构图片预览功能（TODO）

- **背景**：当前本地图片预览主要依赖 `photo_view` / `swipe_image_gallery` 等组合（见 `local_image_gallery_page.dart` 等），桌面与手机的交互仍可统一打磨。
- **桌面（macOS 等）**
  - 支持 **左右方向键** 切换上一张 / 下一张。
  - **长按左方向键或右方向键** 时支持 **连续播放**（按固定间隔自动向前/向后翻页，松手即停；具体间隔与是否与现有缩放/拖拽手势冲突需实现时定）。
- **手机端**
  - 采用更合理的全屏预览方案：**上滑或下滑** 作为主要/辅助退出预览的手势，退出动作要顺手、可发现（可与返回键、点击关闭等并存，避免与横向翻页冲突）。

### 6. 文件夹分享：压缩包与 PDF（TODO）

- **范围**：支持对**文件夹**发起分享（系统分享面板 / 导出等，具体入口与平台能力实现时再定）。
- **压缩包分享**
  - 支持以**压缩包**形式分享（格式与是否加密 ZIP 等实现时再定）。
  - 分享前允许用户输入**压缩包文件名**与**密码**；**默认启用密码保护**，默认密码为 **`8888`**（用户可改或按产品策略允许关闭加密）。
- **PDF 分享**
  - 支持以 **PDF** 形式分享（版式、多图分页、体积与生成性能实现时再定）。
  - 允许用户自定义 **PDF 文件名**；**默认带打开密码**，默认密码为 **`8888`**（用户可改）。

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
