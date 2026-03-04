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

