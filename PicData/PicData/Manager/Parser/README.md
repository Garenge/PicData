# 内容解析器架构重构说明

## 重构目标

将原有的基于switch语句的解析逻辑重构为基于策略模式的模块化架构，提高代码的可维护性、可扩展性和可测试性。

## 新架构设计

### 1. 协议定义 (ContentParserProtocol)

定义了所有解析器需要实现的接口方法：

- `parseContentListWithDocument:sourceModel:` - 解析套图列表
- `getContentModelWithArticleElement:sourceModel:` - 获取单个套图信息
- `parseDetailImagesWithDocument:sourceModel:` - 解析详情页图片
- `parseNextPageForListWithDocument:sourceModel:` - 解析列表的下一页链接
- `parseNextPageForDetailWithDocument:sourceModel:` - 解析列表的下一页链接
- `parseSuggestionsWithDocument:sourceModel:` - 解析推荐内容
- `parsePageTitleWithDocument:href:sourceModel:` - 解析页面标题
- `parseTagsWithDocument:hostModel:` - 解析标签分类
- `getHtmlStringWithData:` - 获取HTML编码类型

### 2. 基础解析器 (BaseContentParser)

提供通用的解析方法和默认实现，减少代码重复：

- `createContentModelWithHref:title:thumbnailUrl:sourceModel:` - 创建内容模型
- `updateCustomContentName:contentHref:sourceModel:` - 更新自定义名称
- `getThumbnailUrlFromImageElement:` - 获取缩略图URL

**重要说明**: 所有具体的解析器类都继承自`BaseContentParser`，这样可以：
- 减少重复代码
- 统一通用的解析逻辑
- 提供默认的协议方法实现
- 便于维护和扩展

### 3. 具体解析器实现

为每个sourceType创建专门的解析器类，**都继承自BaseContentParser**：

- `SourceType3Parser` - 处理sourceType为3的解析逻辑
- `SourceType4Parser` - 处理sourceType为4的解析逻辑
- `SourceType5Parser` - 处理sourceType为5的解析逻辑
- `SourceType10Parser` - 处理sourceType为10的解析逻辑

### 4. 解析器工厂 (ContentParserFactory)

负责根据sourceType创建对应的解析器实例：

- `parserForSourceType:` - 根据sourceType创建解析器
- `supportedSourceTypes` - 获取所有支持的sourceType

## 重构优势

### 1. 职责分离
- 每个解析器只负责一种sourceType的解析逻辑
- 主管理器只负责协调和调用，不再包含具体的解析逻辑

### 2. 易于维护
- 修改某个sourceType的解析逻辑不会影响其他
- 每个类的职责明确，代码更易读

### 3. 易于扩展
- 添加新的sourceType只需创建新的解析器类
- 符合开闭原则：对扩展开放，对修改关闭

### 4. 便于测试
- 可以单独测试每个解析器
- 可以轻松模拟不同的解析器进行单元测试

### 5. 代码复用
- 通过继承BaseContentParser，避免重复代码
- 通用的解析逻辑在基类中统一维护

## 使用方法

### 1. 获取解析器
```objc
id<ContentParserProtocol> parser = [ContentParserFactory parserForSourceType:3];
```

### 2. 使用解析器
```objc
NSArray *results = [parser parseContentListWithDocument:document sourceModel:sourceModel];
NSString *nextPage = [parser parseNextPageWithDocument:document sourceModel:sourceModel];
```

### 3. 添加新的sourceType
1. 创建新的解析器类，**继承自BaseContentParser**
2. 在ContentParserFactory中添加对应的case
3. 实现具体的解析逻辑，复用基类的通用方法

## 继承关系

```
BaseContentParser (基类)
├── SourceType3Parser
├── SourceType4Parser
├── SourceType5Parser
└── SourceType10Parser
```

## 兼容性

重构后的代码保持了原有的公共接口，确保现有代码无需修改即可使用新的架构。

## 注意事项

1. **所有解析器都应该继承BaseContentParser**，而不是直接实现ContentParserProtocol
2. 基类提供了通用的方法实现，子类可以重写需要自定义的逻辑
3. 新增的解析器需要在ContentParserFactory中注册
4. 保持原有的错误处理和边界情况检查
5. 通过继承基类，可以复用通用的解析逻辑，减少代码重复 
