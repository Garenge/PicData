//
//  SourceType10Parser.m
//  PicData
//
//  Created by 鹏鹏 on 2022/5/28.
//  Copyright © 2022 garenge. All rights reserved.
//

#import "SourceType10Parser.h"
#import "AppTool.h"
#import "PicSourceModel.h"
#import "PicContentModel.h"
#import "PicClassModel.h"
#import "PicNetModel.h"

@implementation SourceType10Parser

#pragma mark - ContentParserProtocol

- (NSString *)getHtmlStringWithData:(NSData *)data {
    return [AppTool getStringWithUTF8Code:data];
}

- (NSArray<PicContentModel *> *)parseContentListWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel {
    NSMutableArray *articleContents = [NSMutableArray array];
    
    NSMutableArray *array = [NSMutableArray array];
    for (OCGumboElement *listDiv in document.QueryClass(@"blog")) {
        [array addObjectsFromArray:listDiv.QueryClass(@"items-row")];
    }
    OCQueryObject *articleEs = (OCQueryObject *)array;
    
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
    OCGumboElement *imgE = aE.QueryElement(@"img").firstObject;
    if (!imgE) {
        return nil;
    }
    
    // 获取标题
    title = imgE.attr(@"alt");
    
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
    
    OCGumboElement *contentE = document.QueryClass(@"article-fulltext").firstObject;
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
    OCGumboElement *nextE = document.QueryClass(@"pagination-list").firstObject;
    if (!nextE) {
        return nil;
    }
    
    OCQueryObject *aEs = nextE.QueryElement(@"a");
    NSInteger count = aEs.count;
    NSInteger currentIndex = -1;
    
    for (NSInteger index = 0; index < count; index++) {
        OCGumboElement *aE = aEs[index];
        if ([aE.attr(@"class") containsString:@"is-current"]) {
            currentIndex = index;
            break;
        }
    }
    
    if (currentIndex >= 0 && currentIndex < count - 1) {
        OCGumboElement *aE = aEs[currentIndex + 1];
        return aE.attr(@"href");
    }
    
    return nil;
}

- (NSArray<PicContentModel *> *)parseSuggestionsWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel {
    NSMutableArray *suggestions = [NSMutableArray array];
    
    NSMutableArray *array = [NSMutableArray array];
    for (OCGumboElement *listDiv in document.QueryClass(@"blog")) {
        [array addObjectsFromArray:listDiv.QueryClass(@"items-row")];
    }
    OCQueryObject *articleEs = (OCQueryObject *)array;
    
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
    // SourceType10 暂不支持页面标题解析
    return @"";
}

- (NSArray<PicClassModel *> *)parseTagsWithDocument:(OCGumboDocument *)document 
                                         hostModel:(PicNetModel *)hostModel {
    // SourceType10 暂不支持标签解析
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
    
    // 移除括号内容
    NSString *midString = [preContentTitle splitStringsWithLeadingString:@"\\(" trailingString:@"\\)" error:nil].lastObject;
    if (midString) {
        title = [title stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"(%@)", midString] withString:@""];
    }
    
    // 去除首尾空格
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
    title = [title stringByTrimmingCharactersInSet:whitespace];
    
    // 从URL中提取标识符
    NSString *identifier = [contentHref splitStringWithLeadingString:@".com-" trailingString:@".webp?" error:nil];
    if (identifier.length > 0) {
        title = [NSString stringWithFormat:@"%@ %@", title, identifier];
    }
    
    return title;
}

@end 
