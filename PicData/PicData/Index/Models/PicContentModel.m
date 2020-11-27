//
//  PicContentModel.m
//  PicData
//
//  Created by Garenge on 2020/4/19.
//  Copyright © 2020 garenge. All rights reserved.
//

#import "PicContentModel.h"

@implementation PicContentModel

//+ (NSString *)primaryKey {
//    return @"href";
//}
//
//+ (NSArray *)ignoreColumnNames {
//    return @[@"downloadedCount"];
//}
+ (void)initialize {
    [super initialize];
    Class cls = [self class];
    [[JQFMDB shareDatabase] jq_createTable:NSStringFromClass(cls) dicOrModel:cls];
}

+ (BOOL)unAddALLWithSourceTitle:(NSString *)sourceTitle {
    return [self updateTableWithDicOrModel:@{@"hasAdded": @0} Where:[NSString stringWithFormat:@"where sourceTitle = \"%@\"", sourceTitle]];
}

+ (BOOL)unAddALL {
    return [self updateTableWithDicOrModel:@{@"hasAdded": @0} Where:@""];
}

- (BOOL)updateTable {
    return [self updateTableWhere:[NSString stringWithFormat:@"where href = \"%@\"", self.href]];
}

- (BOOL)deleteFromTable {
    return [PicContentModel deleteFromTable_Where:[NSString stringWithFormat:@"where title = \"%@\"", self.title]];
}

@end
