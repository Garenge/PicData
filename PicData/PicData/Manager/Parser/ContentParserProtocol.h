//
//  ContentParserProtocol.h
//  PicData
//
//  Created by 鹏鹏 on 2022/5/28.
//  Copyright © 2022 garenge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCGumbo.h"

@class PicSourceModel;
@class PicContentModel;
@class PicClassModel;
@class PicNetModel;

NS_ASSUME_NONNULL_BEGIN

@protocol ContentParserProtocol <NSObject>

/// 解析套图列表
- (NSArray<PicContentModel *> *)parseContentListWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel;

/// 获取单个套图信息
- (nullable PicContentModel *)getContentModelWithArticleElement:(OCGumboElement *)articleElement 
                                                   sourceModel:(PicSourceModel *)sourceModel;

/// 解析详情页图片
- (NSArray<NSString *> *)parseDetailImagesWithDocument:(OCGumboDocument *)document 
                                           sourceModel:(PicSourceModel *)sourceModel;

/// 解析下一页链接
- (nullable NSString *)parseNextPageWithDocument:(OCGumboDocument *)document 
                                    sourceModel:(PicSourceModel *)sourceModel;

/// 解析推荐内容
- (NSArray<PicContentModel *> *)parseSuggestionsWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel;

/// 解析页面标题
- (NSString *)parsePageTitleWithDocument:(OCGumboDocument *)document 
                                    href:(NSString *)href 
                              sourceModel:(PicSourceModel *)sourceModel;

/// 解析标签分类
- (NSArray<PicClassModel *> *)parseTagsWithDocument:(OCGumboDocument *)document 
                                         hostModel:(PicNetModel *)hostModel;

/// 获取HTML编码类型
- (NSString *)getHtmlStringWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END 