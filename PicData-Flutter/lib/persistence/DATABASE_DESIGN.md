# PicData Flutter — 本地数据库设计说明

本文档记录与 **Objective-C 版爬虫** 对齐的表结构、封装思路与实现顺序，供后续接入 sqflite / Drift 等实现时使用。

---

## 1. 目标

- 持久化**套图列表**、**下载任务**、**站点来源**等与爬虫相关的数据。
- **高频场景**：每下载一张图可能更新一次进度 → 业务侧用**内存权威 + 节流/批量写库**，避免每张图都同步落盘。
- **可替换后端**：业务只依赖 **Repository 接口 + 领域模型**，具体 SQL/ORM 隔离在实现包内；[`pic_database.dart`](pic_database.dart) 作为统一入口（打开库、版本、释放）。

---

## 2. 表结构（与 OC 一致）

以下为 OC 侧 SQLite DDL，Flutter 实现时应通过 migration 对齐（含类型与主键）。

### 2.1 `PicContentModel` — 套图/内容元数据

| 列 | 类型 | 说明 |
|----|------|------|
| title | TEXT | |
| systemTitle | TEXT | |
| HOST_URL | TEXT | |
| sourceType | INTEGER | 枚举，与 OC 约定一致 |
| sourceHref | TEXT | |
| sourceTitle | TEXT | |
| thumbnailUrl | TEXT | |
| href | TEXT **PRIMARY KEY** | 内容唯一键 |
| isFavor | INTEGER | 如 0/1 |

### 2.2 `PicContentTaskModel` — 下载任务（在内容维度上叠加进度）

在 `PicContentModel` 同名字段基础上增加：

| 列 | 类型 | 说明 |
|----|------|------|
| totalCount | INTEGER | 总张数 |
| downloadedCount | INTEGER | 已下张数 |
| status | INTEGER | 任务状态枚举 |
| createTime | REAL | 时间戳 |
| startTime | REAL | |
| endTime | REAL | |

主键仍为 **href**（与内容一一对应；若未来同一 href 多任务需再拆任务 id）。

### 2.3 `PicSourceModel` — 站点/来源

| 列 | 类型 | 说明 |
|----|------|------|
| title, systemTitle, HOST_URL | TEXT | |
| url | TEXT **PRIMARY KEY** | 来源唯一键 |
| sourceType | INTEGER | |

---

## 3. 索引

OC 侧曾建：

```sql
CREATE INDEX PicContentModel_index ON PicContentModel(href);
CREATE INDEX PicContentTaskModel_index ON PicContentTaskModel(href);
CREATE INDEX PicSourceModel_index ON PicSourceModel(url);
```

在 **SQLite** 中，**PRIMARY KEY 已自带唯一索引**。若主键即为 `href` / `url`，上述单列索引与主键索引**重复**，可省略以减小维护成本；若保留也无功能错误。

**按需补充**（等查询模式确定后再加）：

- 任务列表：`(status)`、`(createTime)` 或联合 `(status, createTime)`。
- 按站点筛内容：`HOST_URL`，或 `(HOST_URL, sourceType)`。

---

## 4. 架构约定

| 层次 | 职责 |
|------|------|
| 领域模型 | `PicContent` / `PicTask` / `PicSource` 等纯 Dart 类型，不依赖 ORM |
| Repository 接口 | 增删改查用语义化方法；进度更新可走 `reportProgress` + 实现内节流 |
| 实现层 | Drift 或 sqflite：表映射、事务、migration、WAL |
| [`PicDatabase`](pic_database.dart) | `init` / `dispose`、schema 版本常量、文件名约定 |

---

## 5. 实现顺序建议

1. 对齐 OC 枚举（`status`、`sourceType` 等）与验收用例（列表、任务、恢复进度）。
2. 添加依赖（如 `drift` + `sqlite3_flutter_libs` 或 `sqflite`），编写 **v1 migration** 对应三张表。
3. 实现各 **Repository**，下载管线只调接口；进度 **节流写** `downloadedCount`（或等价字段）。
4. 可选：从 OC 拷贝 sqlite 的 **导入/迁移工具**（路径、版本校验）。

---

## 6. 文件约定

| 文件 | 说明 |
|------|------|
| `pic_database.dart` | 库入口占位，后续接真实连接与版本 |
| `persistence.dart` | barrel 导出 |
| 本文件 | 设计与表结构备忘 |

---

## 7. 变更记录

| 日期 | 说明 |
|------|------|
| 2026-03-21 | 初稿：OC 三表、索引说明、Repository + 节流策略、实现顺序 |
| 2026-04-06 | Flutter：已落地 `pic_set_download_record` 单表（`PicSetDownloadRecordDao`），冷启动载入并重置非终态；OC 三表其余部分仍待迁移。 |
