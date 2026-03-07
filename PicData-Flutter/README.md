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

### 2. 套图列表交互

- 套图列表需要支持下一页 / 上一页。
- 点击套图，查看套图详情。
- 套图缩略图占位图与加载策略（参考 OC 端的缩略图策略，在 Flutter 端已实现统一占位图 + 图片加载完成后替换展示）。

### 3. 套图详情页（解析与展示）

- 从 tag 列表点击套图 cell，跳转到详情页（当前已有占位页面 `PicDetailPage`，仅展示 `PicContent` 与 `PicHost` 的基本信息）。
- 根据列表传入的 `PicContent.href`，获取详情页的网页内容（HTML）。
- 参考 `Flutter-Spider-Notes.md` 中第 6 节关于 OC 端详情解析的记录，实现 Dart 版详情页解析逻辑：
  - 解析当前详情页的图片列表；
  - 解析“下一页”链接并循环抓取，直到 OC 逻辑中的最终页；
  - 将所有页的图片合并为一套完整图集，在详情页中以列表或瀑布流的方式展示。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
