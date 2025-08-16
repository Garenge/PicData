//
//  PicContentModel.m
//  PicData
//
//  Created by Garenge on 2020/4/19.
//  Copyright © 2020 garenge. All rights reserved.
//

#import "PicContentModel+WCTTableCoding.h"

@implementation PicContentModel

WCDB_IMPLEMENTATION(PicContentModel)
WCDB_SYNTHESIZE(title)
WCDB_SYNTHESIZE(systemTitle)
WCDB_SYNTHESIZE(HOST_URL)

WCDB_SYNTHESIZE(sourceType)
WCDB_SYNTHESIZE(sourceHref)
WCDB_SYNTHESIZE(sourceTitle)
WCDB_SYNTHESIZE(thumbnailUrl)
WCDB_SYNTHESIZE(href)
WCDB_SYNTHESIZE(isFavor)

WCDB_PRIMARY(href)

WCDB_INDEX("_index", href)

- (BOOL)updateTable {
    return [self updateTableWhenHref:self.href];
}

- (BOOL)updateTableWhenHref:(NSString *)href {
    return [[DatabaseManager getDatabase] updateTable:[self.class tableName] setProperties:[self.class allProperties] toObject:self where:self.class.href == self.href];
}

+ (NSArray *)queryTableWithHref:(NSString *)href {
    return [[DatabaseManager getDatabase] getObjectsOfClass:self fromTable:[self tableName] where:self.href == href];
}

+ (NSArray *)queryTableWithSourceHref:(NSString *)sourceHref {
    return [[DatabaseManager getDatabase] getObjectsOfClass:self fromTable:[self tableName] where:self.sourceHref == sourceHref];
}

+ (NSArray *)queryTableWithSourceTitle:(NSString *)sourceTitle {
    return [[DatabaseManager getDatabase] getObjectsOfClass:self fromTable:[self tableName] where:self.sourceTitle == sourceTitle];
}

@end

@implementation PicContentTaskModel

WCDB_IMPLEMENTATION(PicContentTaskModel)

WCDB_SYNTHESIZE(title)
WCDB_SYNTHESIZE(systemTitle)
WCDB_SYNTHESIZE(HOST_URL)

WCDB_SYNTHESIZE(sourceType)
WCDB_SYNTHESIZE(sourceHref)
WCDB_SYNTHESIZE(sourceTitle)
WCDB_SYNTHESIZE(thumbnailUrl)
WCDB_SYNTHESIZE(href)
WCDB_SYNTHESIZE(isFavor)

WCDB_SYNTHESIZE(totalCount)
WCDB_SYNTHESIZE(downloadedCount)
WCDB_SYNTHESIZE(status)

WCDB_SYNTHESIZE(createTime)
WCDB_SYNTHESIZE(startTime)
WCDB_SYNTHESIZE(endTime)

WCDB_PRIMARY(href)

WCDB_INDEX("_index", href)

- (BOOL)insertTable {
    self.createTime = [[NSDate date] timeIntervalSince1970];
    return [super insertTable];
}

/// 利用已有的contentModel初始化一个子类对象
+ (instancetype)taskModelWithContentModel:(PicContentModel *)contentModel {
    NSMutableDictionary *keyValues = [contentModel mj_keyValues];
    PicContentTaskModel *taskModel = [PicContentTaskModel mj_objectWithKeyValues:keyValues];
    taskModel.status = ContentTaskStatusNormal;
    return taskModel;
}

/// 获取下一个任务
+ (NSArray *)queryNextTask {
    return [[DatabaseManager getDatabase] getObjectsOfClass:self fromTable:[self tableName] where:self.status == 0 orders:self.href.asOrder(WCTOrderedAscending) limit:1];
}
/// 获取所有task status为0的任务数
+ (NSInteger)queryCountForTaskStatus:(ContentTaskStatus)status {
    // 假设有一个 MyTable 表
    return [[[[DatabaseManager getDatabase] getValueFromStatement:WCDB::StatementSelect().select([self allProperties].count().distinct()).from([self tableName]).where(self.status == status)] numberValue] integerValue];
}

/// 获取所有tasks status为给定值的任务
+ (NSArray <PicContentTaskModel *>*)queryTasksForStatus:(ContentTaskStatus)status {
    const WCDB::OrderingTerms &orderByCreateTime = self.class.createTime.asOrder(WCTOrderedAscending);
    const WCDB::OrderingTerms &orderByStartTime = self.class.startTime.asOrder(WCTOrderedDescending);
    const WCDB::OrderingTerms &orderByEndTime = self.class.endTime.asOrder(WCTOrderedDescending);

    if (status == ContentTaskStatusNormal) {
        return [[DatabaseManager getDatabase] getObjectsOfClass:self fromTable:[self tableName] where:self.status == status orders:orderByCreateTime];
    } else if (status == ContentTaskStatusStartScane || status == ContentTaskStatusFinishScane) {
        return [[DatabaseManager getDatabase] getObjectsOfClass:self fromTable:[self tableName] where:self.status == status orders:orderByStartTime];
    } else if (status == ContentTaskStatusFinishDownload) {
        return [[DatabaseManager getDatabase] getObjectsOfClass:self fromTable:[self tableName] where:self.status == status orders:orderByEndTime];
    } else {
        return @[];
    }
}

/// 获取所有task status为给定值的任务数
+ (NSInteger)queryCountForTaskInStatus12 {
    return [[[DatabaseManager getDatabase] getValueFromStatement:WCDB::StatementSelect().select([self allProperties].count().distinct()).from([self tableName]) .where(self.status == 1 || self.status == 2)] numberValue].integerValue;
}

- (BOOL)updateTable {
    if (self.status == 1) {
        self.startTime = [[NSDate date] timeIntervalSince1970];
    } else if (self.status == 3) {
        self.endTime = [[NSDate date] timeIntervalSince1970];
    }
    return [self updateTableWhenHref:self.href];
}

- (BOOL)updateTableWithStatus {
    if (self.status == 1) {
        self.startTime = [[NSDate date] timeIntervalSince1970];
        return [[DatabaseManager getDatabase] updateTable:[self.class tableName] setProperties:{self.class.status, self.class.startTime} toObject:self where:self.class.href == self.href];
    } else if (self.status == 3) {
        self.endTime = [[NSDate date] timeIntervalSince1970];
        return [[DatabaseManager getDatabase] updateTable:[self.class tableName] setProperties:{self.class.status, self.class.endTime} toObject:self where:self.class.href == self.href];
    } else {
        return [[DatabaseManager getDatabase] updateTable:[self.class tableName] setProperties:self.class.status toObject:self where:self.class.href == self.href];
    }
}

- (BOOL)updateTableWithStartTime {
    return [[DatabaseManager getDatabase] updateTable:[self.class tableName] setProperties:self.class.startTime toObject:self where:self.class.href == self.href];
}

- (BOOL)updateTableWithEndTime {
    return [[DatabaseManager getDatabase] updateTable:[self.class tableName] setProperties:self.class.endTime toObject:self where:self.class.href == self.href];
}

/// 初始化所有进程中任务
+ (BOOL)resetHalfWorkingTasks {
    [[DatabaseManager getDatabase] updateTable:[self tableName] setProperty:self.status toValue:@3 where:self.downloadedCount > 0 && self.downloadedCount == self.totalCount];
    // 更新多列数据
    return [[DatabaseManager getDatabase] updateTable:[self tableName] setProperties:{self.status, self.downloadedCount} toRow:@[@0, @0] where:self.downloadedCount >= 0 && self.status != 3];
}

/// 初始化所有任务
+ (BOOL)resetToZeroAllTasks {
    // 更新多列数据
    return [[DatabaseManager getDatabase] updateTable:[self tableName] setProperties:{self.status, self.downloadedCount} toRow:@[@0, @0] where:self.downloadedCount >= 0 && self.status == 3];
}

+ (BOOL)deleteFromTableWithSourceTitle:(NSString *)sourceTitle {
    return [[DatabaseManager getDatabase] deleteFromTable:[self tableName] where:self.sourceTitle == sourceTitle];
}

+ (BOOL)deleteFromTableWithSourceHref:(NSString *)sourceHref {
    return [[DatabaseManager getDatabase] deleteFromTable:[self tableName] where:self.sourceHref == sourceHref];
}

+ (BOOL)deleteFromTableWithTitle:(NSString *)title {
    return [[DatabaseManager getDatabase] deleteFromTable:[self tableName] where:self.title == title];
}

/// 取消已添加任务, 根据href
+ (BOOL)deleteFromTableWithHref:(NSString *)href {
    return [[DatabaseManager getDatabase] deleteFromTable:[self tableName] where:self.href == href];
}

@end
