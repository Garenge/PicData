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

## 文档索引

- 首页列表右侧索引实现：`homepage_list_index_guide.md`
- 缩略图占位图与加载策略：`thumbnail_loading_strategy.md`
- 站点解析规则总览：`doc/parsing_rules.md`
- Flutter 抓取与解析实践笔记：`flutter_spider_notes.md`
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
