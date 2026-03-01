# PicData

本仓库包含 PicData 项目的多版本实现，支持在 iPhone、iPad 和 Mac 上运行。

## 项目结构

### PicData (Objective-C)

- **目录**: `PicData/`
- **说明**: 使用 Objective-C 开发的原始版本，基于 iOS / Mac Catalyst
- **详细文档**: [PicData-OC-README.md](./PicData-OC-README.md)

### PicData-Flutter

- **目录**: `PicData-Flutter/`
- **说明**: 使用 Flutter 重写的新版本，一套代码多端运行
- **支持平台**: iPhone、iPad、Mac (macOS)

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
