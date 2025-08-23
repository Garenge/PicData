//
//  BaseContentParser.m
//  PicData
//
//  Created by 鹏鹏 on 2022/5/28.
//  Copyright © 2022 garenge. All rights reserved.
//

#import "BaseContentParser.h"
#import "PicSourceModel.h"
#import "PicContentModel.h"
#import "PicClassModel.h"
#import "PicNetModel.h"

@implementation BaseContentParser

#pragma mark - ContentParserProtocol (默认实现)

- (NSString *)getHtmlStringWithData:(NSData *)data {
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSArray<PicContentModel *> *)parseContentListWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel {
    // 子类需要重写此方法
    return @[];
}

- (nullable PicContentModel *)getContentModelWithArticleElement:(OCGumboElement *)articleElement 
                                                   sourceModel:(PicSourceModel *)sourceModel {
    // 子类需要重写此方法
    return nil;
}

- (NSArray<NSString *> *)parseDetailImagesWithDocument:(OCGumboDocument *)document 
                                           sourceModel:(PicSourceModel *)sourceModel {
    // 子类需要重写此方法
    return @[];
}

- (nullable NSString *)parseNextPageWithDocument:(OCGumboDocument *)document 
                                    sourceModel:(PicSourceModel *)sourceModel {
    // 子类需要重写此方法
    return nil;
}

- (NSArray<PicContentModel *> *)parseSuggestionsWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel {
    // 子类需要重写此方法
    return @[];
}

- (NSString *)parsePageTitleWithDocument:(OCGumboDocument *)document 
                                    href:(NSString *)href 
                              sourceModel:(PicSourceModel *)sourceModel {
    // 子类需要重写此方法
    return @"";
}

- (NSArray<PicClassModel *> *)parseTagsWithDocument:(OCGumboDocument *)document 
                                         hostModel:(PicNetModel *)hostModel {
    // 子类需要重写此方法
    return @[];
}

#pragma mark - 通用方法

- (PicContentModel *)createContentModelWithHref:(NSString *)href
                                         title:(NSString *)title
                                   thumbnailUrl:(NSString *)thumbnailUrl
                                    sourceModel:(PicSourceModel *)sourceModel {
    PicContentModel *contentModel = [[PicContentModel alloc] init];
    contentModel.href = href;
    contentModel.sourceType = sourceModel.sourceType;
    contentModel.sourceHref = sourceModel.url;
    contentModel.referer = sourceModel.referer;
    contentModel.sourceTitle = sourceModel.title;
    contentModel.HOST_URL = sourceModel.HOST_URL;
    contentModel.title = title;
    contentModel.thumbnailUrl = thumbnailUrl;
    
    return contentModel;
}

- (NSString *)updateCustomContentName:(NSString *)preContentTitle
                          contentHref:(NSString *)contentHref
                          sourceModel:(PicSourceModel *)sourceModel {
    // 子类可以重写此方法实现自定义逻辑
    return preContentTitle;
}

- (NSString *)getThumbnailUrlFromImageElement:(OCGumboElement *)imgE {
    NSString *thumbnailUrl = imgE.attr(@"src");
    if (!thumbnailUrl || thumbnailUrl.length == 0) {
        thumbnailUrl = imgE.attr(@"data-src");
    }
    thumbnailUrl = [thumbnailUrl stringByReplacingOccurrencesOfString:@"i0.wp.com/" withString:@""];
    
    return thumbnailUrl;
}

@end 