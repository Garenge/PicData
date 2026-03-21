## PicData Flutter 解析规则概览

**目标**：在 Flutter 端复用 OC 端的解析思路，实现「按 `sourceType` 选择不同解析规则，从 HTML 中提取套图列表、详情图片、下一页链接等信息」。

当前 OC 端的解析代码位于 `PicData/PicData/Manager/Parser`，采用策略模式，根据 `sourceType` 选择不同的解析器类：

- **协议层 (`ContentParserProtocol`)**：定义所有站点解析器共同需要实现的方法。
- **基类层 (`BaseContentParser`)**：封装公共逻辑（创建内容模型、更新标题、自定义名称、获取缩略图 URL 等）。
- **具体解析器层 (`SourceType3Parser` / `4` / `5` / `10`)**：针对每个 `sourceType` 的 DOM 结构实现具体的解析逻辑。
- **工厂层 (`ContentParserFactory`)**：根据 `sourceType` 返回对应解析器实例。

在 Flutter 端，我们可以用 Dart 重建一套等价的结构，配合 `PicNetConfig` / `PicHost` 模型和各个 `sourceType` 的站点配置。

---

## 一、核心模型与职责映射

- **PicNetConfig / PicHost（Flutter）**
  - 对应 OC 端的 Host / Source 配置。
  - 字段中的 `sourceType` 决定了使用哪一套解析规则。

- **ContentParserProtocol（OC） → Dart 接口**
  - 需要定义的能力：
    - **列表页解析**：解析套图列表（标题、封面、小图/链接等）。
    - **详情页解析**：解析套图详情中的所有图片 URL。
    - **分页解析**：列表页 / 详情页的下一页链接。
    - **推荐内容**：详情页推荐列表（可选）。
    - **页面标题**：从 `<title>` 或页面结构中提取标题（可选）。
    - **标签分类**：解析 tags / 分类页（部分站点支持）。
    - **HTML 解码**：原始 `Data` → HTML 字符串（Flutter 一般直接是 `String`，可以简单处理）。

- **BaseContentParser（OC） → Dart 抽象基类**
  - 封装通用能力：
    - 解析上下文：`document` / `sourceModel` / `href` / `htmlString`。
    - 公共工具方法：
      - 创建内容模型 `ContentModel`（href、title、thumbnail、source info）。
      - 针对不同站点的标题修正（追加 ID、去除括号等）。
      - 从 `img` 元素中获取图片 URL（`src` / `data-src` 等）。

- **SourceTypeXParser（OC） → Dart 具体解析器**
  - 每个 `sourceType` 对应一个 Dart 解析器，实现接口/继承基类：
    - `SourceType3Parser` → 解析 hitxhot 等站点。
    - `SourceType4Parser` → 解析 meirentu。
    - `SourceType5Parser` → 解析 tuzac。
    - `SourceType10Parser` → 解析 buondua。

---

## 二、OC 各 `sourceType` 的关键规则总结

下面只是结构性的概览，具体 DOM 选择器规则后续可以按站点逐条补充和迁移到 Dart。

### 1. `sourceType = 3`（例如：`https://www.hitxhot.org`）

- **列表页 (`parseContentListWithDocument`)**
  - 列表容器：`div.HCRIN`
  - 每个套图节点：容器内的 `div.VVAHRQFF`
  - 对每个 `articleElement`：
    - 主链接：第一个 `a` 标签 → `href`
    - 封面图：第一个 `img` 元素。
    - 标题：`div.GZDHFYIQ` 下第一个 `a` 的文本。
    - 标题后处理：`updateCustomContentName`（可自定义规则）。
    - 缩略图 URL：`getThumbnailUrlFromImageElement(imgE)`。

- **详情图 (`parseDetailImagesWithDocument`)**
  - 容器：`div.VKSUBTSWA`
  - 详情页中的所有 `img` → `src` 作为图片 URL。

- **列表下一页 (`parseNextPageForListWithDocument`)**
  - 容器：`.nav-next`
  - 在里面找文本为 `"→"`（或包含 `"→"`）的 `a`，取 `href`，再基于 `HOST_URL` 补全绝对地址。

- **详情下一页 (`parseNextPageForDetailWithDocument`)**
  - 容器：`.nav-links`
  - 在里面找文本为 `"Next >"`（或包含 `"Next >"`）的 `a`，取 `href`，基于 `HOST_URL` 转为绝对地址。

- **推荐内容 (`parseSuggestionsAsyncCompletion`)**
  - 当前 HTML 中从 `<script>` 查找 `var initRelated=` 段落。
  - 抽取 `tag: [...]` 的 JSON 片段，拼成 `/related?page=1&tag=...&cb=recommendedFn` 请求。
  - GET 获取 JSON 数组：
    - 字段：`id`（href）、`title`、`image`（缩略图）。
    - 创建推荐的 `PicContentModel` 列表。

- **页面标题 (`parsePageTitleWithDocument`)**
  - `head > title` 文本类似：`" Hit-x-Hot: Vol. 4832 XXX | Page 1/5"`。
  - 有 `" | Page"` 时，取中间 `" Hit-x-Hot: "` 与 `" | Page"` 之间的内容。
  - 否则去掉 `" Hit-x-Hot: "` 前缀。

### 2. `sourceType = 4`（例如：`https://meirentu.cc`）

- **列表页**
  - 列表容器：`div.update_area_content`
  - 套图项：`.i_list`
  - 每个套图：
    - 主链接：`articleElement` 下第一个 `a` 的 `href`。
    - 封面图：这个 `a` 内的第一个 `img`。
    - 标题：`.meta-title` 元素的文本。
    - 标题后处理：`updateCustomContentName` 默认原样返回。
    - 缩略图 URL：`getThumbnailUrlFromImageElement(imgE)`。

- **详情图**
  - 容器：`.content`
  - 容器下所有 `img` 的 `src`。

- **列表下一页**
  - 容器：`.page`
  - 在其中找到文本为 `"下页"` 的 `a`，取 `href`，基于 `HOST_URL` 转为绝对地址。

- **推荐内容**
  - 容器：`.update_area_lists`
  - 套图项：`.i_list`，规则同列表页。

- **页面标题**
  - 当前实现：返回空字符串（可按需在 Flutter 端补齐）。

- **标签分类 (`parseTagsWithDocument`)**
  - 容器：`.tag_cloud`
  - 其中所有 `a` 标签：
    - `href`：拼接到 `HOST_URL` 并进行 URL 编码。
    - 文本：作为子分类标题。
    - 生成 `PicSourceModel`（子分类），再包装为 `PicClassModel`，总标题固定为 `"标签"`。

### 3. `sourceType = 5`（例如：`https://www.tuzac.com`）

- **HTML 编码**
  - 直接用 `UTF8` 解码。

- **列表页**
  - 列表容器：`.content`
  - 套图项：`.clearfix`
  - 每个套图：
    - 主链接：第一个 `a` 的 `href`。
    - 封面图：第一个 `img`。
    - 标题：`img` 的 `title` 属性。
    - 标题后处理：`updateCustomContentName`：
      - 若标题非空，则从 `contentHref` 提取最后一段路径（去掉扩展名）作为 ID，并 `"{title} {id}"` 形式追加，保证唯一性。
    - 缩略图 URL：`getThumbnailUrlFromImageElement(imgE)`。

- **详情图**
  - 容器：`.file-detail`
  - 其中所有 `img` 的 `src`。

- **列表下一页**
  - 容器：`#pager`
  - 在 `a` 元素中找到文本为 `"下一页 ›"` 或包含该文本的 `a`，取其 `href`，基于 `HOST_URL` 补全。

- **推荐内容**
  - 容器：`.related-files`
  - 套图项：`.clearfix`，规则同列表页。

- **页面标题**
  - `head > title`，和 `sourceType3` 相似逻辑：
    - 含 `" | Page"` 时取其中的主标题。
    - 否则去掉 `" Hit-x-Hot: "` 前缀（当前实现复用了示例逻辑，可按实际页面调整）。

- **标签**
  - 当前实现：不支持标签解析，返回空数组。

### 4. `sourceType = 10`（例如：`https://buondua.com`）

- **列表页**
  - 整体容器：`.blog`
  - 在每个 `.blog` 下收集 `.items-row`，合并为列表。
  - 每个套图：
    - 主链接：第一个 `a` 的 `href`。
    - 封面图：该 `a` 内的第一个 `img`。
    - 标题：`img` 的 `alt` 属性。
    - 标题后处理：`updateCustomContentName`：
      - 去掉标题中圆括号 `()` 内的子串（若有）。
      - 去除首尾空格。
      - 从 `contentHref` 里用规则 `".com-"` 到 `".webp?"` 截取一个 identifier，并追加到尾部（`"{title} {identifier}"`）。
    - 缩略图 URL：`getThumbnailUrlFromImageElement(imgE)`。

- **详情图**
  - 容器：`.article-fulltext`
  - 其中所有 `img` 的 `src`。

- **列表下一页**
  - 容器：`.pagination-list`
  - 遍历内部 `a`：
    - 找到 `class` 中包含 `"is-current"` 的当前页 `a`，取其下一个兄弟 `a` 的 `href` 作为下一页。

- **推荐内容**
  - 规则与列表页类似：`.blog` → `.items-row`。

- **页面标题 / 标签**
  - 当前实现：页面标题空字符串；标签解析不支持。

---

## 三、Flutter 侧建议的解析接口设计

### 1. Dart 协议接口（对应 `ContentParserProtocol`）

建议在 Flutter 中定义一个解析接口，例如：

```dart
abstract class ContentParser {
  /// 解析套图列表
  List<PicContent> parseContentList(String html, PicHost host);

  /// 解析详情页所有图片 URL
  List<String> parseDetailImages(String html, PicHost host);

  /// 列表页下一页 URL（可为 null）
  String? parseNextPageForList(String html, PicHost host);

  /// 详情页下一页 URL（可为 null）
  String? parseNextPageForDetail(String html, PicHost host);

  /// 推荐内容（可空列表）
  List<PicContent> parseSuggestions(String html, PicHost host);

  /// 页面标题（可空字符串）
  String parsePageTitle(String html, PicHost host);

  /// 标签分类
  List<PicTagClass> parseTags(String html, PicHost host);
}
```

> 说明：`PicContent`、`PicTagClass` 等模型可以根据 Flutter 现有数据结构补充定义。

### 2. Dart 基类（对应 `BaseContentParser`）

基类可以提供：

- HTML 解析辅助（基于如 `html` 包，将字符串转 DOM）。
- 公共上下文属性：
  - 当前 HTML 字符串、当前 URL / href、当前 `PicHost` / `sourceType`。
- 公共工具方法：
  - 创建内容模型。
  - 标题增强 / 清洗（根据 OC 中的 `updateCustomContentName` 规则）。
  - 从 `img` 元素抽取 `src`、`data-src` 等。

---

## 四、Flutter 侧解析器工厂设计

参考 OC 中 `ContentParserFactory`：

```dart
class ContentParserFactory {
  static ContentParser? parserForSourceType(int? sourceType) {
    switch (sourceType) {
      case 3:
        return SourceType3Parser();
      case 4:
        return SourceType4Parser();
      case 5:
        return SourceType5Parser();
      case 10:
        return SourceType10Parser();
      default:
        return null;
    }
  }

  static const supportedSourceTypes = <int>{3, 4, 5, 10};
}
```

后续当你为 Flutter 端补充具体解析实现时，可以：

- 逐个 `sourceType` 迁移 OC 里的 DOM 选择器规则（类名 / 标签结构），改写为 Dart DOM 查询。
- 在新建的各个 `SourceTypeXParser` 中，照着本文件中的章节实现列表/详情/分页/推荐/标签解析。

---

## 五、下一步工作建议

- **1. 确认 Flutter 端需要支持的功能范围**
  - 若当前只需要“详情页图片 URL 列表”，可以只先实现 `parseDetailImages`，逐步扩展。

- **2. 按站点逐步迁移**
  - 优先实现 `sourceType = 3 / 4 / 5 / 10` 四个站点的 `parseDetailImages` 与 `parseContentList`。

- **3. 当你给出具体站点的 HTML 示例时**
  - 可以在 Dart 中精准还原 OC 里面的解析逻辑，或者针对新站点定义新 `sourceType` 和解析器。
