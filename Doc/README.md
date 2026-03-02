# Doc

本目录用于存放 PicData 项目相关文档，后续可放置设计说明、接口文档、迁移记录等。

## Flutter 模型解析注意点

- Flutter/Dart 使用的是**严格 JSON 解析**，不能像 iOS 某些 JSON 解析器那样容忍数组/对象尾部多余逗号。
  - 示例：`[1, 2, 3,]` 在 OC 里可能能解析，在 Dart 的 `json.decode` 里会报错。
  - 建议：**尽量把配置文件改成合法 JSON**，避免在解析前做字符串清洗。
- Flutter 运行时不支持 MJExtension 那种基于反射的“自动模型映射”，常见做法有两种：
  - **手写 `fromJson` / `toJson`**（当前 `PicNetConfig`、`PicHost`、`PicUrl` 采用的方式）。
  - 使用 `json_serializable` 等代码生成工具，用注解 + 命令自动生成解析代码（后续可以考虑迁移）。
- 当前实现中，`PicNetService` 负责从 `assets/config/PicNet.json` 加载数据并解析为 Dart 模型：
  - 解析结果通过**全局单例**方式暴露，后续界面可以直接访问配置数据，而不需要在每个页面重复解析。
