//
//  PicSourceModel.m
//  PicData
//
//  Created by Garenge on 2020/4/19.
//  Copyright © 2020 garenge. All rights reserved.
//

#import "PicSourceModel+WCTTableCoding.h"

@implementation PicSourceModel

WCDB_IMPLEMENTATION(PicSourceModel)
WCDB_SYNTHESIZE(title)
WCDB_SYNTHESIZE(systemTitle)
WCDB_SYNTHESIZE(HOST_URL)
WCDB_SYNTHESIZE(url)
WCDB_SYNTHESIZE(sourceType)

WCDB_PRIMARY(url)

WCDB_INDEX("_index", url)

- (id)copy {
    PicSourceModel *sourceModel = [PicSourceModel mj_objectWithKeyValues:[self mj_keyValues]];
    return sourceModel;
}

+ (NSArray *)queryTableWithUrl:(NSString *)url {
    return [[DatabaseManager getDatabase] getObjectsOfClass:self fromTable:[self tableName] where:self.url == url];
}

@end
