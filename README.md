# PicData

本仓库包含 PicData 项目的多版本实现，支持在 iPhone、iPad 和 Mac 上运行。

## 项目结构

### PicData (Objective-C)

- **目录**: `PicData/`
- **说明**: 使用 Objective-C 开发的原始版本，基于 iOS / Mac Catalyst
- **详细文档**: [PicData-OC-README.md](./PicData-OC-README.md)

### PicData-Flutter

- **目录**: `PicData-Flutter/`
- **说明**: 使用 Flutter 重写的新版本，一套代码多端运行，内置轻量级“爬虫”能力，用于抓取公开图片站点的标签、列表等结构化数据（仅做导航与聚合，不存储图片本体）。
- **支持平台**: iPhone、iPad、Mac (macOS)

#### 爬虫 / 抓取相关功能简介

- **配置驱动站点**：通过 `assets/config/PicNet.json` 配置多家图片站点（Host），包括入口 URL、搜索格式、标签等。
- **按站点搜索词管理**：为不同 Host 配置独立的 `searchKeys`，在 Flutter 端按选中 Host 动态切换搜索关键字列表。
- **轻量抓取能力**：Flutter 端使用 HTTP 请求 + HTML 解析，对公开页面进行结构化提取（如标题、封面链接、标签等），仅获取必要元数据。
- **合规与使用边界**：仅用于个人学习和技术探索，不鼓励大规模抓取或违反目标站点使用条款的行为。

#### 新建 Flutter 工程

1. **前置条件**：已安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)，并确保 `flutter doctor` 检查通过（尤其 iOS 和 macOS 所需工具链）。

2. **在现有目录中创建项目**（`PicData-Flutter/` 目录已预留，在其中初始化）：

   ```bash
   cd PicData-Flutter
   flutter create . --project-name pic_data
   ```

   - `--project-name pic_data`：使用 Dart 规范的 snake_case 命名；可省略，默认会取目录名 `pic_data_flutter`。
   - 若目录非空，Flutter 会提示确认，输入 `y` 继续。

3. **启用目标平台**（如未自动启用）：

   ```bash
   flutter config --enable-ios
   flutter config --enable-macos
   ```

4. **运行项目**：

   ```bash
   # iPhone 模拟器
   flutter run -d ios

   # iPad 模拟器（在 Xcode 中切换设备）
   flutter run -d ios

   # Mac 桌面
   flutter run -d macos
   ```

5. **检查可用设备**：`flutter devices`

## Doc

`Doc/` 目录用于存放项目相关文档，便于后续查阅与维护。
