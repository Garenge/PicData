//
//  SourceType4Parser.m
//  PicData
//
//  Created by 鹏鹏 on 2022/5/28.
//  Copyright © 2022 garenge. All rights reserved.
//

#import "SourceType4Parser.h"
#import "AppTool.h"
#import "PicSourceModel.h"
#import "PicContentModel.h"
#import "PicClassModel.h"
#import "PicNetModel.h"

@implementation SourceType4Parser

#pragma mark - ContentParserProtocol

- (NSString *)getHtmlStringWithData:(NSData *)data {
    return [AppTool getStringWithUTF8Code:data];
}

- (NSArray<PicContentModel *> *)parseContentListWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel {
    NSMutableArray *articleContents = [NSMutableArray array];
    
    OCGumboElement *listDiv = document.QueryClass(@"update_area_content").firstObject;
    if (!listDiv) {
        return @[];
    }
    
    OCQueryObject *articleEs = listDiv.QueryClass(@"i_list");
    
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
    OCGumboElement *tE = articleElement.QueryClass(@"meta-title").firstObject;
    if (tE) {
        title = tE.text();
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
    NSMutableArray *urls = [NSMutableArray array];
    
    OCGumboElement *contentE = document.QueryClass(@"content").firstObject;
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

- (nullable NSString *)parseNextPageWithDocument:(OCGumboDocument *)document 
                                    sourceModel:(PicSourceModel *)sourceModel {
    OCGumboElement *nextE = document.QueryClass(@"page").firstObject;
    if (!nextE) {
        return nil;
    }
    
    OCQueryObject *aEs = nextE.QueryElement(@"a");
    NSString *nextPageTitle = @"下页";
    
    for (OCGumboElement *aE in aEs) {
        if ([aE.text() isEqualToString:nextPageTitle]) {
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
    
    OCGumboElement *listDiv = document.QueryClass(@"update_area_lists").firstObject;
    if (!listDiv) {
        return @[];
    }
    
    OCQueryObject *articleEs = listDiv.QueryClass(@"i_list");
    
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
    // SourceType4 暂不支持页面标题解析
    return @"";
}

- (NSArray<PicClassModel *> *)parseTagsWithDocument:(OCGumboDocument *)document 
                                         hostModel:(PicNetModel *)hostModel {
    NSMutableArray *classModelsM = [NSMutableArray array];
    
    OCQueryObject *tagsListEs = document.QueryClass(@"tag_cloud");
    
    for (OCGumboElement *tagsListE in tagsListEs) {
        PicClassModel *classModel = [self getClassModelWithHostModel:hostModel withTagsListElement:tagsListE];
        [classModelsM addObject:classModel];
    }
    
    return [classModelsM copy];
}

#pragma mark - Private Methods

- (NSString *)updateCustomContentName:(NSString *)preContentTitle 
                          contentHref:(NSString *)contentHref 
                          sourceModel:(PicSourceModel *)sourceModel {
    // SourceType4 暂不需要自定义名称处理
    return preContentTitle;
}

- (PicClassModel *)getClassModelWithHostModel:(PicNetModel *)hostModel 
                           withTagsListElement:(OCGumboElement *)tagsListE {
    OCQueryObject *aEs = tagsListE.QueryElement(@"a");
    
    NSMutableArray *subTitles = [NSMutableArray array];
    for (OCGumboElement *aE in aEs) {
        NSString *href = aE.attr(@"href");
        
        PicSourceModel *sourceModel = [[PicSourceModel alloc] init];
        sourceModel.sourceType = hostModel.sourceType;
        
        NSString *url = [[hostModel.HOST_URL stringByAppendingPathComponent:href] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *subTitle = aE.text();
        
        sourceModel.url = url;
        sourceModel.title = subTitle;
        sourceModel.HOST_URL = hostModel.HOST_URL;
//        [sourceModel insertTable];
        
        [subTitles addObject:sourceModel];
    }

    [PicSourceModel insertTableWithModels:subTitles];

    PicClassModel *classModel = [PicClassModel modelWithHOST_URL:hostModel.HOST_URL 
                                                           Title:@"标签" 
                                                       sourceType:hostModel.sourceType 
                                                       subTitles:subTitles];
    
    return classModel;
}

@end 
