## Flutter 爬虫 / HTML 抓取笔记

本项目在 Flutter 端只做**轻量级抓取**：发起 HTTP 请求，解析公开页面的 HTML，从中抽取结构化信息（如标题、标签、封面 URL 等），不做大规模、高频爬取。

---

### 1. 基本技术栈

- **HTTP 请求**
  - 推荐：`http` 或 `dio`
  - 典型用法：

    ```dart
    import 'package:http/http.dart' as http;

    final resp = await http.get(
      Uri.parse('https://example.com'),
      headers: {
        'User-Agent': 'PicData-Flutter/1.0',
        'Referer': 'https://example.com',
      },
    );
    ```

- **HTML 解析**
  - 推荐：`html` 包（`package:html/parser.dart`）
  - 把字符串解析成 DOM，然后用选择器提取元素：

    ```dart
    import 'package:html/parser.dart' as html_parser;
    import 'package:html/dom.dart';

    Document document = html_parser.parse(resp.body);
    final links = document.querySelectorAll('a'); // 所有 <a> 标签
    ```

---

### 2. 典型抓取流程

1. **准备配置**
   - 在 `PicNet.json` 中配置每个 Host 的入口 URL、`searchFormat`、`referer` 等。
   - 通过 `PicHost` 模型封装这些信息，便于在 Flutter 中统一处理。

2. **构造请求 URL**
   - 例如：`https://site.com/search?q=%@`，在 Flutter 中把 `%@` 替换为搜索词（必要时 URL encode）。

3. **发起请求**
   - 带上必要的 `User-Agent` / `Referer` / Cookie（若站点有简单防护）。

4. **解析 HTML**
   - 使用 `html_parser.parse` 获得 `Document`。
   - 使用 `querySelector` / `querySelectorAll` 配合 CSS 选择器，例如：
     - `.item` / `.post-card` / `ul.list > li`
     - `.thumb img` 获取封面图
     - `.title a` 获取标题和详情链接

5. **映射到模型**
   - 把解析到的字段转换为 Dart 模型（如 `PicItem`），用于 UI 展示。

---

### 3. 简单示例：解析列表页

```dart
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

class PicItem {
  PicItem({required this.title, required this.coverUrl, required this.detailUrl});

  final String title;
  final String coverUrl;
  final String detailUrl;
}

Future<List<PicItem>> fetchPicItems(String listUrl) async {
  final resp = await http.get(Uri.parse(listUrl));
  if (resp.statusCode != 200) {
    throw Exception('请求失败: ${resp.statusCode}');
  }

  final Document doc = html_parser.parse(resp.body);
  final List<PicItem> items = [];

  for (final el in doc.querySelectorAll('.item')) {
    final titleEl = el.querySelector('.title a');
    final imgEl = el.querySelector('img');

    if (titleEl == null || imgEl == null) continue;

    final title = titleEl.text.trim();
    final detailUrl = titleEl.attributes['href'] ?? '';
    final coverUrl = imgEl.attributes['src'] ?? '';

    if (title.isEmpty || detailUrl.isEmpty || coverUrl.isEmpty) continue;

    items.add(PicItem(
      title: title,
      coverUrl: coverUrl,
      detailUrl: detailUrl,
    ));
  }

  return items;
}
```

> 注意：CSS 选择器 `.item` / `.title a` / `img` 等需要根据目标站点的实际 HTML 结构调整。

---

### 4. Flutter 端做爬虫的限制与建议

- **平台差异**
  - 移动端 / 桌面：可以直接用 `http` 请求大多数站点。
  - Web：受浏览器 CORS 限制，很多第三方站点不能直接请求，通常需要后端代理。

- **性能与 UI**
  - HTML 解析是 CPU 密集操作，列表很大时建议：
    - 控制单页数据量；
    - 或在需要时放到 `Isolate`（如 `compute`）中避免阻塞 UI。

- **反爬与合法性**
  - 遵守目标站点的 `robots.txt`、服务条款及所在地区法律法规。
  - 控制请求频率，避免对目标站点造成压力。
  - 仅抓取必要的公开元数据，不用于商业或批量分发。

---

### 5. 与本项目的结合点

- `PicNet.json` 中的各个 Host（`PicHost`）描述了目标站点的基础信息。
- `searchKeys` 列表为每个站点提供常用搜索关键字，结合 `searchFormat` 构造搜索 URL。
- 将来如果扩展：
  - 可以在 Flutter 端根据 `PicHost` 的配置，调用统一的“抓取适配器”函数；
  - 不同站点可通过配置 + 少量解析函数适配；
  - 如需求增长，建议把复杂的爬虫逻辑迁移到后端服务，由 Flutter 只消费 API。

---

### 6. iOS（OC）端套图解析逻辑概览（PicData/Manager/Parser）

这一部分是对 OC 端解析实现的“读代码笔记”，便于在 Flutter 里复用思路。

#### 6.1 整体架构：工厂 + 协议 + 具体解析器

- **核心参与类**
  - `ContentParserManager`：任务调度 & 下载任务管理（包括队列、通知、状态流转），同时提供一些解析相关的静态方法。
  - `ContentParserManager (Parser)`：在分类里封装“解析入口”，对外暴露统一的接口（解析列表、详情、tag、标题等）。
  - `ContentParserFactory`：根据 `sourceType` 创建具体站点的解析器，如 `SourceType3Parser`、`SourceType4Parser`、`SourceType5Parser`、`SourceType10Parser`。
  - `ContentParserProtocol`：约定解析器必须实现的接口（列表解析、详情图片解析、下一页、推荐、标题、标签等）。
  - `BaseContentParser`：协议的默认空实现 + 公共工具（如创建 `PicContentModel`、取缩略图 URL、上下文保存）。
  - `SourceTypeXParser`：不同站点的具体解析器，实现协议中真正的 DOM 解析逻辑。
  - `ParseOperation`：一个异步 `NSOperation`，负责**从详情页递归请求多页 HTML + 调用解析 + 写入 urlList.txt + 通知下载管理器**。

- **站点多样性抽象方式**
  - 每个站点在 `PicSourceModel.sourceType` 上有一个 int 标记。
  - `ContentParserFactory.parserForSourceType:` 根据这个标记返回对应的 `SourceTypeXParser`。
  - 上层 `ContentParserManager` / `ParseOperation` **只面向协议 `ContentParserProtocol` 编程**，不关心具体站点 DOM。

从 Flutter 角度，可以用一个 Dart 接口 + 多个实现类来对应这个结构。

#### 6.2 套图列表解析与翻页逻辑

- **统一列表解析入口**
  - OC 端入口：`ContentParserManager+Parser.parseContentListWithHtmlString:sourceModel:completeHandler:`
  - 处理流程：
    1. 使用 `OCGumboDocument` 把 `htmlString` 解析成 DOM。
    2. 通过 `ContentParserFactory.parserForSourceType(sourceModel.sourceType)` 拿到具体的 `parser`。
    3. 调用 `parser.parseContentListWithDocument:sourceModel:` 拿到 `[PicContentModel]` 列表。
    4. 调用 `refreshContentListDownloadStatus:` 给每个 `PicContentModel` 标记是否已在下载任务中（`hasAddedToDLTasks`）。
    5. 调用 `parser.parseNextPageForListWithDocument:sourceModel:` 获取**列表页下一页的链接字符串**。
    6. 如果 `nextPage` 不为空，则用 `sourceModel.HOST_URL` 做 `relativeToURL` 拼成 `nextPageURL` 返回。

- **不同站点列表 DOM 差异（部分示例）**
  - `SourceType3Parser`
    - 列表容器：`document.QueryClass(@"HCRIN").firstObject`
    - 每个套图节点：`listDiv.QueryClass(@"VVAHRQFF")`
    - `getContentModelWithArticleElement:` 中会：
      - 取 `<a>` 的 `href`
      - 从特定 class 的 `<h>` / `<a>` 里取标题
      - 从 `<img>` 取缩略图 URL
  - `SourceType4Parser`
    - 列表容器：`update_area_content`
    - item class：`i_list`
    - 翻页区域：class `page`，在其中找文本为“下页”的 `<a>`。
  - `SourceType5Parser`
    - 列表容器：class `content`
    - item class：`clearfix`
    - 翻页区域：`id="pager"`，在其中找文本为“下一页 ›”的 `<a>`。
  - `SourceType10Parser`
    - 列表容器：class `blog` 下的 `items-row`
    - 翻页区域：class `pagination-list`，记录当前 `<a>` 上带 `is-current` class 的索引，取后一项作为下一页。

- **列表页翻页的统一模式**
  - 每个 `SourceTypeXParser` 在 `parseNextPageForListWithDocument:` 里用各自的 CSS/DOM 规则：
    - **找到翻页区域节点**（如 `nav-next`、`page`、`pager`、`pagination-list`）。
    - 在其中遍历 `<a>`，根据文本（“→”、“下页”、“下一页 ›”）或 class（`is-current`）确定下一页的 `<a>`。
    - 返回 `<a>` 的 `href`，有些解析器会直接返回绝对 URL，有些返回相对路径由上层再拼。
  - 上层 `ContentParserManager+Parser` 只关心：
    - **是否有下一页 (`nextPage.length > 0`)**。
    - 如果有，就拼出 `NSURL *nextPageURL`；如果没有，则认为列表已经到尾页。

在 Flutter 端，你可以直接复用这个思路：**一个统一的“列表解析接口” + 多个具体站点的 CSS 选择器实现 + 返回 `items` + `nextPageUrl`**。

#### 6.3 套图详情页解析流程

- **详情解析入口**
  - OC 端入口：`ContentParserManager+Parser.parseDetailWithHtmlString:href:sourceModel:preNextUrl:needSuggest:completeHandler:`
  - 流程：
    1. 判空 `htmlString`，为空直接回调空结果。
    2. 用 `OCGumboDocument` 解析 HTML。
    3. 通过工厂拿到 parser。
    4. 调用 `parser.setParseContextWithDocument:sourceModel:href:htmlString:` 把当前上下文保存到解析器里（方便异步推荐等）。
    5. 调用 `parser.parseDetailImagesWithDocument:sourceModel:` 得到当前页的所有图片 URL。
    6. 调用 `parser.parseNextPageForDetailWithDocument:sourceModel:` 得到**详情页下一页的链接字符串**（可能复用列表的逻辑，Base 中默认是调用 `parseNextPageForList...`）。
    7. 如需推荐，调用 `parser.parseSuggestionsWithDocument:sourceModel:` 并再走一遍 `refreshContentListDownloadStatus:`。
    8. 调用 `parser.parsePageTitleWithDocument:href:sourceModel:` 得到该套图的统一标题（内部会做一些“补唯一性”的处理）。
    9. 把这几个结果一起通过 block 回传。

- **不同站点的详情 DOM 差异（部分示例）**
  - `SourceType3Parser`
    - 详情页图片区域：class `VKSUBTSWA` 下的全部 `<img src="...">`。
    - 详情下一页：class `nav-links` 下 `<a>` 文本包含 `"Next >"`。
  - `SourceType4Parser`
    - 详情图片：class `content` 下所有 `<img>`。
    - 详情下一页：没有专门重写，默认继承 Base 行为（与列表相同逻辑）。
  - `SourceType5Parser`
    - 详情图片：class `file-detail` 下所有 `<img>`。
  - `SourceType10Parser`
    - 详情图片：class `article-fulltext` 下所有 `<img>`。

- **标题统一和“补唯一性”**
  - `SourceType3Parser.parsePageTitleWithDocument:` 会从 `<head><title>` 中解析，如：
    - 原始 `title1`: `"Hit-x-Hot: Vol. 4832 可乐Vicky | Page 1/5"`
    - 截取 `" Hit-x-Hot: "` 与 `" | Page"` 之间的部分作为标题。
    - 再调用 `updateCustomContentName:`，通常会把 `href` 中的 id 拼到标题后，确保本地文件夹名更唯一。
  - `SourceType5Parser`、`SourceType10Parser` 也会在 `updateCustomContentName:` 中基于 URL 做额外处理，例如去掉括号附加信息、从 URL 里提取某个 id 追加到标题里。

在 Flutter 端，可以对应实现一个 `DetailParseResult`，包含：`images`, `nextPage`, `suggestions`, `title`，由不同站点解析器返回。

#### 6.4 详情页多页遍历 & 直到最终页的判断

- **驱动多页遍历的类：`ParseOperation`**
  - `ParseOperation` 继承自自定义的异步 Operation（`PPCustomAsyncOperation`），核心职责：
    - **从套图详情的首页开始，请求 HTML**。
    - 调用 `ContentParserManager.dealWithHtmlData:...` 解析出当前页所有图片 URL & 下一页 URL。
    - 把当前页的图片 URL 通过 `middleWriteHandler` 追加写入 `urlList.txt`。
    - 调用 `PDDownloadManager.downWithSource:ContentTaskModel:urls:referer:suggestNames:` 真正开始下图。
    - 如果存在 `nextUrl`，递归调用 `requestHtmlStringWithUrl:nextUrl` 继续下一页。
    - 如果 `nextUrl` 为空，则认为已到**最后一页**，调用 `taskCompleteHandler(totalCount)` 并结束 Operation。

- **关键代码逻辑（简化后的流程）**
  - `initWithSourceModel:contentTaskModel:` 中：
    - `pageCount` 初始为 1，`picCount` 为 0。
    - `mainOperationDoBlock` 里调用 `requestHtmlStringWithUrl:contentTaskModel.href` 开始从详情首页抓取。
  - `requestHtmlStringWithUrl:`：
    1. 用 `sourceModel.HOST_URL` + 传入的 `url` 组装出 `taskURL`。
    2. 通过 `PDRequest getWithURL:taskURL` 请求 HTML。
    3. 成功后用 `ContentParserManager.getHtmlStringWithData:sourceType:` 根据站点编码拿到 `content` 字符串。
    4. 调用  
       `ContentParserManager.dealWithHtmlData:content referer:taskURL.absoluteString nextUrl:url WithSourceModel:sourceModel ContentTaskModel:contentTaskModel picCount:picCount`
       - 内部会：
         - 调 `parseDetailWithHtmlString:...` 拿到 `imageUrls` & `nextPage`。
         - 生成对应的建议文件名 `["(picCount+1).jpg", ...]`。
         - 拼接本页的 URL 文本 `urlsString`。
         - 调用 `PDDownloadManager` 去下这些图片。
         - 返回一个 `NSDictionary`，包含：
           - `"nextUrl"`：下一页相对 URL（可能为空）。
           - `"urls"`：当前页所有图片 URL 的字符串（带换行）。
           - `"count"`：当前页图片数量。
    5. `ParseOperation` 拿到 `result`：
       - `nextUrl = result[@"nextUrl"]`
       - `count = [result[@"count"] intValue]`
       - 通过 `middleWriteHandler` 把 `result[@"urls"]` 追加写入 `urlList.txt`。
    6. **终止条件 & 递归：**
       - 如果 `nextUrl` 为空或长度为 0：
         - 认为已经到达**最后一页**。
         - 调用 `taskCompleteHandler(self.picCount + count)`，即总图数 = 之前页数累计图数 + 当前页图数。
         - 调用 `finishOperation` 结束本次 Operation。
       - 否则：
         - `pageCount += 1`
         - `picCount += count`
         - 再次调用 `requestHtmlStringWithUrl:nextUrl` 进入下一页。

- **注意点**
  - “是否还有下一页”的唯一依据是各 `SourceTypeXParser` 在 `parseNextPageForDetailWithDocument:` 里能否解析出一个非空的 `nextPage` 字符串。
  - 因为**解析网页比下载图片快很多**，`ContentParserManager.prepareToDoNextTask:` 里还有一层控制：当前状态为 1/2 的任务数量超过一定数（>4）时就暂时不继续启动新的解析任务，防止任务堆积。

在 Flutter 中，你可以类似地实现一个“多页详情遍历器”：每次请求详情页 -> 解析图片 & nextUrl -> 累计图片并开始下载 -> 如果 nextUrl 为空则结束，否则递归或循环下一页。
