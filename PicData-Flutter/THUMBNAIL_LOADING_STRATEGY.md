# 缩略图与占位图加载策略（Flutter）

本文档说明 `PicData-Flutter` 当前的缩略图展示策略，目标是让列表和推荐区在弱网/无图场景下依然稳定可读，并尽量避免闪烁和布局抖动。

## 1. 目标

- 统一视觉：有图和无图时都保持稳定卡片结构。
- 平滑过渡：优先展示占位图，网络图加载完成后无跳变替换。
- 异常兜底：缩略图缺失或请求失败时，界面可继续浏览。

## 2. 核心实现位置

- 通用网格组件：`lib/pages/Home/gallery/pic_content_grid.dart`
- 列表页网格项：`lib/pages/Home/gallery/tag_gallery_page.dart`
- 详情页推荐区：`lib/pages/Home/gallery/pic_detail_page.dart`

其中，缩略图策略的关键在两个页面里的 `_GalleryThumbnail` 组件实现（当前逻辑保持一致）。

## 3. 加载策略设计

### 3.1 无缩略图 URL

当 `imageUrl` 为空时，直接渲染 `_buildPlaceholder(...)`：

- 使用主题色 `surfaceVariant` + 渐变做背景；
- 中间展示 `collections_outlined` 图标和“套图”文案；
- 保持卡片顶部圆角和边框风格一致。

这样即使服务端不返回缩略图，也不会出现破图或空白块。

### 3.2 有缩略图 URL

使用 `Stack` 分层：

1. 底层先渲染占位图（立即可见）；
2. 上层 `CachedNetworkImage` 异步加载网络图；
3. 网络图成功后覆盖占位图，实现自然替换。

关键点：

- `placeholder` 返回 `SizedBox.shrink()`，避免重复叠加 loading；
- `errorWidget` 也返回 `SizedBox.shrink()`，失败时保留底层占位图；
- `fit: BoxFit.cover` 保证网格缩略图填充一致。

## 4. 为什么这样做

- 避免“先白块后出图”的跳闪：占位图始终先出现。
- 避免错误态破坏布局：网络失败不会出现不一致的错误组件尺寸。
- 便于统一迭代：列表页和详情推荐区共用同一套视觉思路。

## 5. 与详情大图页的区别

详情页大图（`pic_detail_page.dart`）使用 `CachedNetworkImage` 的 `placeholder/errorWidget` 展示显式加载圈与破图图标，这与缩略图策略不同：

- 缩略图：强调列表稳定和快速浏览，失败后保持“静态占位”。
- 大图：强调单图状态反馈，允许用户明确感知“正在加载/加载失败”。

两者并行可以兼顾浏览效率和状态可见性。

## 6. 后续可选优化

- 统一抽出公共 `GalleryThumbnail` 组件文件，减少页面内重复定义。
- 对关键域名开启预热或低分辨率预览，提升首屏体感。
- 为占位图增加站点级差异化样式（可选），便于快速识别来源。
