//
//  NSDictionary+ppEx.h
//  HiconicsEMS
//
//  Created by ex_liuzp9 on 2025/2/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary<__covariant KeyType, __covariant ObjectType> (ppEx)

/// 生成新的数组, 回调返回重新生成的符合要求的对象
- (NSArray *)mapArray:(id(^)(ObjectType element, KeyType key))block;

/// 过滤符合条件的元素, 生成新的字典
- (NSDictionary <KeyType, ObjectType> *)filter:(BOOL(^)(ObjectType element, KeyType key))block;

/// 一键枚举, for循环, index
- (void)enumeration:(void(^)(ObjectType element, KeyType key))block;

@end

NS_ASSUME_NONNULL_END
