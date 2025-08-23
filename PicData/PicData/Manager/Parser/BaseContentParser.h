//
//  BaseContentParser.h
//  PicData
//
//  Created by 鹏鹏 on 2022/5/28.
//  Copyright © 2022 garenge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContentParserProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface BaseContentParser : NSObject <ContentParserProtocol>

/// 创建内容模型的通用方法
- (PicContentModel *)createContentModelWithHref:(NSString *)href
                                         title:(NSString *)title
                                   thumbnailUrl:(NSString *)thumbnailUrl
                                    sourceModel:(PicSourceModel *)sourceModel;

/// 更新自定义内容名称的通用方法
- (NSString *)updateCustomContentName:(NSString *)preContentTitle
                          contentHref:(NSString *)contentHref
                          sourceModel:(PicSourceModel *)sourceModel;

/// 获取缩略图URL的通用方法
- (NSString *)getThumbnailUrlFromImageElement:(OCGumboElement *)imgE;

@end

NS_ASSUME_NONNULL_END 