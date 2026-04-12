# pic_data

导航类 Flutter 客户端，用于展示 PicNet 配置生成的入口和图集内容。

## TODO

### 1. 图片并发下载数量 + 设置持久化（TODO）

- 队列 B（单图下载）当前为固定最大并发（代码里常量，现为 3）；需改为**可配置**，并设合理上下限；**后期目标参考：单图同时下载任务数上限约 20**（具体默认值与档位产品可再定）。
- 在「设置」页增加配置项，修改后立即作用于 `PicDownloadModule`（或统一从单例读取）。
- **本地持久化**：使用 `SharedPreferences`（与下载根路径一致）或项目内已有配置存储方式保存键值，冷启动恢复。
- 生效策略（建议口径，便于验收）：
  - 新入队的队列 A 任务：使用最新的并发配置；
  - 已在队列 B 运行中的任务：可选择「不中断，直到当前批次/整套完成」或「立即调整并发」（二选一，先实现简单策略）。

> 下载主体流程已可用；本节选为待补充的产品与工程细节。

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
- **后期考虑**：支持 **最多同时 3 套图并发**（解析/拉图流水线在架构上允许多套并行时的上限）；需与队列 B 单图并发（见「### 2」）、站点限流与下载记录状态展示一并设计。

### 5. 重构图片预览功能（TODO）

- **背景**：当前本地图片预览主要依赖 `photo_view` / `swipe_image_gallery` 等组合（见 `local_image_gallery_page.dart` 等），桌面与手机的交互仍可统一打磨。
- **桌面（macOS 等）**
  - 支持 **左右方向键** 切换上一张 / 下一张。
  - **长按左方向键或右方向键** 时支持 **连续播放**（按固定间隔自动向前/向后翻页，松手即停；具体间隔与是否与现有缩放/拖拽手势冲突需实现时定）。
- **手机端**
  - 采用更合理的全屏预览方案：**上滑或下滑** 作为主要/辅助退出预览的手势，退出动作要顺手、可发现（可与返回键、点击关闭等并存，避免与横向翻页冲突）。

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
