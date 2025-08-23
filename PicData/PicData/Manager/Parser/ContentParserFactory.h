//
//  ContentParserFactory.h
//  PicData
//
//  Created by 鹏鹏 on 2022/5/28.
//  Copyright © 2022 garenge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContentParserProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface ContentParserFactory : NSObject

/// 根据sourceType创建对应的解析器
/// @param sourceType 数据源类型
/// @return 对应的解析器实例，如果没有找到返回nil
+ (nullable id<ContentParserProtocol>)parserForSourceType:(int)sourceType;

/// 获取所有支持的sourceType
+ (NSArray<NSNumber *> *)supportedSourceTypes;

@end

NS_ASSUME_NONNULL_END 