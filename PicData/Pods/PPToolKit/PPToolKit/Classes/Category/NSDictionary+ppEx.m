//
//  NSDictionary+ppEx.m
//  HiconicsEMS
//
//  Created by ex_liuzp9 on 2025/2/11.
//

#import "NSDictionary+ppEx.h"

@implementation NSDictionary (ppEx)

/// 生成新的数组, 回调返回重新生成的符合要求的对象
- (NSArray *)mapArray:(id  _Nonnull (^)(id _Nonnull, id _Nonnull))block {
    if (!block) { return @[]; }
    NSMutableArray *array = [NSMutableArray array];
    NSArray *allKeys = [self allKeys];
    for (id key in allKeys) {
        id object = self[key];
        [array addObject:block(object, key)];
    }
    return array;
}

/// 过滤符合条件的元素, 生成新的字典
- (NSDictionary *)filter:(BOOL (^)(id _Nonnull, id _Nonnull))block {
    if (!block) { return @{}; }

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSArray *allKeys = [self allKeys];
    for (id key in allKeys) {
        id object = self[key];
        if (block(object, key)) {
            [dict setValue:object forKey:key];
        }
    }
    return dict;
}

/// 一键枚举, for循环, index
- (void)enumeration:(void (^)(id _Nonnull, id _Nonnull))block {
    if (!block) { return; }

    NSArray *allKeys = [self allKeys];
    for (id key in allKeys) {
        id object = self[key];
        block(object, key);
    }
}

@end
