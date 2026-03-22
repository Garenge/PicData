# 文件网格自适应布局说明

本文档说明 `lib/pages/files/file_browser_page.dart` 中文件网格 UI 的宽度自适配策略，目标是让文件卡片在不同屏幕宽度下保持稳定密度，不出现“无脑放大”。

## 设计目标

- 在手机、平板、桌面上保持一致的视觉节奏。
- 优先通过“增加列数”利用宽屏，而不是放大单个卡片。
- 保持网格整体居中，避免超宽屏时卡片贴边或分布不均。
- 为后续单独调整文件卡片（cell）样式提供独立组件入口。

## 核心参数

- `targetItemWidth = 190`：单个卡片的目标宽度。
- `minItemWidth = 160`：单个卡片的最小可接受宽度。
- `gridSpacing = 12`：横向/纵向间距。
- `maxColumns = 6`：最大列数上限，避免极宽屏下单行过多导致可读性下降。

## 布局算法

1. 先按目标宽度估算列数：
   - `columns = floor(maxWidth / (targetItemWidth + spacing))`
   - 并限制在 `1..maxColumns`
2. 根据列数反推出网格总宽度 `gridWidth`，再计算左右留白 `sidePadding`。
3. 将 `sidePadding` 作用到 `GridView` 水平内边距，使网格整体水平居中。
4. 根据当前有效宽度推导 `childAspectRatio`，使 cell 高度随宽度平滑变化，避免宽屏下卡片过高或过矮。

## 结构拆分

- 页面主逻辑：`FileBrowserPageState`
  - 目录读取、排序、刷新、导航、平台能力判断。
- 单个卡片：`_FileGridItem`
  - 统一封装文件/文件夹 cell 的图标、标题、副标题、点击反馈。

后续若要调整单个文件 UI（类似 iOS `UICollectionViewCell`），优先在 `_FileGridItem` 内修改，不影响目录读取与网格计算逻辑。
