# HomePage 列表模式右侧索引开发说明

本文档说明 `HomePage` 在列表模式下右侧字母索引栏的实现机制，便于后续维护和迭代。

## 1. 代码位置

- 主文件：`lib/pages/Home/home_page.dart`
- 关键方法：`_buildListView(List<HomeEntry> entries)`
- 相关状态：
  - `_viewType`：控制标签模式 / 列表模式切换
  - `_listController`：控制列表滚动与索引跳转

## 2. 功能目标

- 将入口列表按稳定顺序展示为 `ListView`
- 在右侧提供字母索引栏（`#` + `A-Z`）
- 点击某个字母后，快速滚动到该字母分组的首条数据

## 3. 数据准备与分组逻辑

`_buildListView` 内部的核心步骤如下：

1. 继承上游排序结果
   - 当前逻辑不在列表模式内重新排序（`sortedEntries = [...entries]`）
   - 上游在 `build()` 中已按拼音排序，保证顺序一致

2. 提取索引字母
   - 使用 `lpinyin` 的 `PinyinHelper.getShortPinyin(...)`
   - 取拼音首字母并转大写
   - 非 `A-Z` 的字符统一归类为 `#`

3. 建立首项映射
   - `firstIndexByLetter: Map<String, int>`
   - 遍历列表，仅记录每个字母第一次出现的位置

4. 生成索引栏顺序
   - 从 `firstIndexByLetter.keys` 生成 `indexLetters`
   - 排序时将 `#` 固定到最前，其余按字母序

## 4. 右侧索引交互与滚动定位

右侧索引栏是一个窄列（`SizedBox(width: 32)`）+ `GestureDetector` 文本项：

- 点击字母时，读取 `firstIndexByLetter[letter]`
- 目标 offset 使用固定行高计算：`48.0 * targetIndex`
- 通过 `_listController.animateTo(...)` 触发平滑滚动
  - `duration: 200ms`
  - `curve: Curves.easeOut`

这个实现成立的前提是：左侧 `ListView.builder` 使用固定 `itemExtent: 48`。

## 5. 现有实现的优点

- 逻辑简单，性能稳定（O(n) 构建索引映射）
- 依赖固定 `itemExtent`，滚动定位成本低
- 对中文标题友好（拼音首字母索引）
- 非字母字符有统一兜底（`#`）

## 6. 已知约束与注意事项

- 如果未来 `ListTile` 高度变成动态，`48.0 * index` 会失准
- 当某些字母没有数据时，不会显示该字母（只显示存在分组）
- 当前索引栏无“拖拽滑动连续定位”，仅支持点击跳转
- 右侧索引没有当前高亮状态（可作为后续增强）

## 7. 建议的迭代方向

- 增加“当前字母高亮”和轻量提示浮层（例如中间大字母）
- 支持索引栏拖拽连续跳转（类似通讯录体验）
- 若后续改为动态高度列表，可改为：
  - 记录每个分组的像素 offset，或
  - 使用分组锚点方案替代 `itemExtent` 乘法定位

## 8. 快速自测清单

- 切换到列表模式后，右侧索引可见且可点击
- 点击 `#` / `A` / 其它字母，列表跳到对应首条项
- 中文标题能按拼音首字母正确归组
- 非字母开头标题归入 `#`
- 数据源切换后，索引仍与当前列表匹配
