//
//  SourceType5Parser.m
//  PicData
//
//  Created by 鹏鹏 on 2022/5/28.
//  Copyright © 2022 garenge. All rights reserved.
//

#import "SourceType5Parser.h"
#import "AppTool.h"
#import "PicSourceModel.h"
#import "PicContentModel.h"
#import "PicClassModel.h"
#import "PicNetModel.h"

@implementation SourceType5Parser

#pragma mark - ContentParserProtocol

- (NSString *)getHtmlStringWithData:(NSData *)data {
    // SourceType5 使用默认编码
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSArray<PicContentModel *> *)parseContentListWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel {
    NSMutableArray *articleContents = [NSMutableArray array];
    
    OCGumboElement *listDiv = document.QueryClass(@"list").firstObject;
    if (!listDiv) {
        return @[];
    }
    
    OCQueryObject *articleEs = listDiv.QueryClass(@"piece");
    
    for (OCGumboElement *articleE in articleEs) {
        PicContentModel *contentModel = [self getContentModelWithArticleElement:articleE sourceModel:sourceModel];
        if (contentModel) {
            [contentModel insertTable];
            [articleContents addObject:contentModel];
        }
    }
    
    return [articleContents copy];
}

- (nullable PicContentModel *)getContentModelWithArticleElement:(OCGumboElement *)articleElement 
                                                   sourceModel:(PicSourceModel *)sourceModel {
    OCGumboElement *aE = articleElement.QueryElement(@"a").firstObject;
    if (!aE) {
        return nil;
    }
    
    NSString *href = aE.attr(@"href");
    NSString *title = aE.attr(@"title");
    
    // 获取图片元素
    OCGumboElement *imgE = aE.QueryElement(@"img").firstObject;
    if (!imgE) {
        return nil;
    }
    
    // 更新自定义内容名称
    title = [self updateCustomContentName:title contentHref:href sourceModel:sourceModel];
    
    // 获取缩略图URL（使用基类方法）
    NSString *thumbnailUrl = [self getThumbnailUrlFromImageElement:imgE];
    
    // 创建内容模型（使用基类方法）
    return [self createContentModelWithHref:href 
                                     title:title 
                               thumbnailUrl:thumbnailUrl 
                                sourceModel:sourceModel];
}

- (NSArray<NSString *> *)parseDetailImagesWithDocument:(OCGumboDocument *)document 
                                           sourceModel:(PicSourceModel *)sourceModel {
    // SourceType5 暂不支持详情页图片解析
    return @[];
}

- (nullable NSString *)parseNextPageWithDocument:(OCGumboDocument *)document 
                                    sourceModel:(PicSourceModel *)sourceModel {
    // SourceType5 暂不支持下一页解析
    return nil;
}

- (NSArray<PicContentModel *> *)parseSuggestionsWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel {
    // SourceType5 暂不支持推荐内容解析
    return @[];
}

- (NSString *)parsePageTitleWithDocument:(OCGumboDocument *)document 
                                    href:(NSString *)href 
                              sourceModel:(PicSourceModel *)sourceModel {
    // SourceType5 暂不支持页面标题解析
    return @"";
}

- (NSArray<PicClassModel *> *)parseTagsWithDocument:(OCGumboDocument *)document 
                                         hostModel:(PicNetModel *)hostModel {
    // SourceType5 暂不支持标签解析
    return @[];
}

#pragma mark - Private Methods

- (NSString *)updateCustomContentName:(NSString *)preContentTitle 
                          contentHref:(NSString *)contentHref 
                          sourceModel:(PicSourceModel *)sourceModel {
    // SourceType5 暂不需要自定义名称处理
    return preContentTitle;
}

@end 