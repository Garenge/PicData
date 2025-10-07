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
    
    OCGumboElement *listDiv = document.QueryClass(@"content").firstObject;
    if (!listDiv) {
        return @[];
    }
    
    OCQueryObject *articleEs = listDiv.QueryClass(@"clearfix");

    for (OCGumboElement *articleE in articleEs) {
        PicContentModel *contentModel = [self getContentModelWithArticleElement:articleE sourceModel:sourceModel];
        if (contentModel) {
//            [contentModel insertTable];
            [articleContents addObject:contentModel];
        }
    }
    [PicContentModel insertTableWithModels:articleContents];

    return [articleContents copy];
}

- (nullable PicContentModel *)getContentModelWithArticleElement:(OCGumboElement *)articleElement 
                                                   sourceModel:(PicSourceModel *)sourceModel {
    OCGumboElement *aE = articleElement.QueryElement(@"a").firstObject;
    if (!aE) {
        return nil;
    }
    
    NSString *href = aE.attr(@"href");
    NSString *title = @"";
    
    // 获取图片元素
    OCGumboElement *imgE = articleElement.QueryElement(@"img").firstObject;
    if (!imgE) {
        return nil;
    }
    
    // 获取标题
    title = imgE.attr(@"title");
    
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
    NSMutableArray *urls = [NSMutableArray array];
    
    OCGumboElement *contentE = document.QueryClass(@"file-detail").firstObject;
    if (!contentE) {
        return @[];
    }
    
    OCQueryObject *es = contentE.Query(@"img");
    for (OCGumboElement *e in es) {
        NSString *src = e.attr(@"src");
        if (src.length > 0) {
            [urls addObject:src];
        }
    }
    
    return [urls copy];
}

- (nullable NSString *)parseNextPageForListWithDocument:(OCGumboDocument *)document 
                                    sourceModel:(PicSourceModel *)sourceModel {
    OCGumboElement *nextE = document.QueryID(@"pager").firstObject;
    if (!nextE) {
        return nil;
    }
    
    OCQueryObject *aEs = nextE.QueryElement(@"a");
    NSString *nextPageTitle = @"下一页 ›";

    for (OCGumboElement *aE in aEs) {
        if ([aE.text() isEqualToString:nextPageTitle] || [aE.text() containsString:nextPageTitle]) {
            NSString *nextPage = aE.attr(@"href");
            if (nextPage.length > 0) {
                return [NSURL URLWithString:nextPage relativeToURL:[NSURL URLWithString:sourceModel.HOST_URL]].absoluteString;
            }
            break;
        }
    }
    
    return nil;
}

- (NSArray<PicContentModel *> *)parseSuggestionsWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel {
    NSMutableArray *suggestions = [NSMutableArray array];
    
    OCGumboElement *listDiv = document.QueryClass(@"related-files").firstObject;
    if (!listDiv) {
        return @[];
    }
    
    OCQueryObject *articleEs = listDiv.QueryClass(@"clearfix");

    for (OCGumboElement *articleE in articleEs) {
        PicContentModel *contentModel = [self getContentModelWithArticleElement:articleE sourceModel:sourceModel];
        if (contentModel) {
//            [contentModel insertTable];
            [suggestions addObject:contentModel];
        }
    }
    [PicContentModel insertTableWithModels:suggestions];

    return [suggestions copy];
}

- (NSString *)parsePageTitleWithDocument:(OCGumboDocument *)document 
                                    href:(NSString *)href 
                              sourceModel:(PicSourceModel *)sourceModel {
    NSString *title = @"";
    
    OCGumboElement *headE = document.QueryElement(@"head").firstObject;
    OCGumboElement *titleE = headE.QueryElement(@"title").firstObject;
    if (titleE) {
        NSString *title1 = titleE.text();
        // title1 => "Hit-x-Hot: Vol. 4832 可乐Vicky | Page 1/5"
        if ([title1 containsString:@" | Page"]) {
            // 对str字符串进行匹配
            title = [title1 splitStringWithLeadingString:@" Hit-x-Hot: " trailingString:@" | Page" error:nil];
        } else {
            title = [title1 stringByReplacingOccurrencesOfString:@" Hit-x-Hot: " withString:@""];
        }
    }
    
    return [self updateCustomContentName:title contentHref:href sourceModel:sourceModel];
}

- (NSArray<PicClassModel *> *)parseTagsWithDocument:(OCGumboDocument *)document 
                                         hostModel:(PicNetModel *)hostModel {
    // SourceType3 暂不支持标签解析
    return @[];
}

#pragma mark - Private Methods

- (NSString *)updateCustomContentName:(NSString *)preContentTitle 
                          contentHref:(NSString *)contentHref 
                          sourceModel:(PicSourceModel *)sourceModel {
    if (preContentTitle.length == 0) {
        return preContentTitle;
    }
    
    NSString *title = preContentTitle;
    
    // 追加指定名称 提高唯一性
    NSString *identifier = [contentHref.lastPathComponent stringByDeletingPathExtension];
    title = [NSString stringWithFormat:@"%@ %@", title, identifier];
    
    return title;
}

@end 
