//
//  SourceType3Parser.m
//  PicData
//
//  Created by 鹏鹏 on 2022/5/28.
//  Copyright © 2022 garenge. All rights reserved.
//

#import "SourceType3Parser.h"
#import "AppTool.h"
#import "PicSourceModel.h"
#import "PicContentModel.h"
#import "PicClassModel.h"
#import "PicNetModel.h"

@implementation SourceType3Parser

#pragma mark - ContentParserProtocol

- (NSString *)getHtmlStringWithData:(NSData *)data {
    return [AppTool getStringWithUTF8Code:data];
}

- (NSArray<PicContentModel *> *)parseContentListWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel {
    NSMutableArray *articleContents = [NSMutableArray array];
    
    OCGumboElement *listDiv = document.QueryClass(@"HCRIN").firstObject;
    if (!listDiv) {
        return @[];
    }
    
    OCQueryObject *articleEs = listDiv.QueryClass(@"VVAHRQFF");
    
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
    OCGumboElement *hE = articleElement.QueryClass(@"GZDHFYIQ").firstObject;
    if (hE) {
        OCGumboElement *tE = hE.QueryElement(@"a").firstObject;
        if (tE) {
            title = tE.text();
        }
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
    
    OCGumboElement *contentE = document.QueryClass(@"VKSUBTSWA").firstObject;
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
    OCGumboElement *nextE = document.QueryClass(@"nav-next").firstObject;
    if (!nextE) {
        return nil;
    }
    
    OCQueryObject *aEs = nextE.QueryElement(@"a");
    NSString *nextPageTitle = @"→";
    
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

- (nullable NSString *)parseNextPageForDetailWithDocument:(OCGumboDocument *)document sourceModel:(PicSourceModel *)sourceModel {
    OCGumboElement *nextE = document.QueryClass(@"nav-links").firstObject;
    if (!nextE) {
        return nil;
    }
    
    OCQueryObject *aEs = nextE.QueryElement(@"a");
    NSString *nextPageTitle = @"Next >";
    
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
    return @[];
//    NSMutableArray *suggestions = [NSMutableArray array];
//
//    OCQueryObject *articleEs = document.QueryClass(@"VMUVXRX");
//
//    for (OCGumboElement *articleE in articleEs) {
//        PicContentModel *contentModel = [self getContentModelWithArticleElement:articleE sourceModel:sourceModel];
//        if (contentModel) {
////            [contentModel insertTable];
//            [suggestions addObject:contentModel];
//        }
//    }
//    [PicContentModel insertTableWithModels:suggestions];
//
//    return [suggestions copy];
}

- (void)parseSuggestionsAsyncCompletion:(void (^)(NSArray<PicContentModel *> * _Nonnull))completion {
    // SourceType3 特殊, 推荐列表是异步获取的
    // 判空
    if (NSStringLengthOfString(self.htmlString) == 0 || NSStringLengthOfString(self.currentHref) == 0 || self.currentDocument == nil || self.currentSourceModel == nil) {
        PPIsBlockExecute(completion, @[]);
        return;
    }

    // https://www.hitxhot.org/related?page=1&tag=["Pretty","Body"]&cb=recommendedFn
    // 解析, 拿到initRelated
    OCQueryObject *scripts = self.currentDocument.QueryElement(@"script");

    NSString *tagString = nil;
    for (OCGumboElement *scriptE in scripts) {
        NSString *script = scriptE.text();
        if (![script containsString:@"var initRelated="]) {
            continue;
        }
        NSLog(@"script = %@", script);
        tagString = [self extractTagString:script];
    }

    if (NSStringLengthOfString(tagString) == 0) {
        PPIsBlockExecute(completion, @[]);
        return;
    }

    NSString *relatedUrl = [NSString stringWithFormat:@"/related?page=1&tag=%@&cb=recommendedFn", tagString];
    NSURL *url = [NSURL URLWithString:relatedUrl relativeToURL:[NSURL URLWithString:self.currentSourceModel.HOST_URL]];
    if (url) {
        [PDRequest getWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"related data = \n%@", dataString);
            NSString *jsonString = [dataString splitStringWithLeadingString:@"recommendedFn\\(" trailingString:@"\\);" error:nil];
            NSArray *jsonArray = [NSJSONSerialization getJsonFromString:jsonString];

            NSMutableArray *suggestions = [NSMutableArray array];
            for (NSDictionary *dict in jsonArray) {
                NSString *href = dict[@"id"];
                NSString *title = dict[@"title"];
                NSString *thumbnailUrl = dict[@"image"];
                PicContentModel *contentModel = [self createContentModelWithHref:href
                                                                           title:title
                                                                    thumbnailUrl:thumbnailUrl
                                                                     sourceModel:self.currentSourceModel];
                if (contentModel) {
                    [suggestions addObject:contentModel];
                }
            }
            [PicContentModel insertTableWithModels:suggestions];

            PPIsBlockExecute(completion, suggestions);
        }];
    }
}

- (NSString *)extractTagString:(NSString *)htmlContent {
    // 找到 "tag: ["
    NSRange startRange = [htmlContent rangeOfString:@"tag: ["];
    if (startRange.location == NSNotFound) {
        return nil;
    }
    
    // 找到对应的 "]"
    NSRange endRange = [htmlContent rangeOfString:@"]" options:0 range:NSMakeRange(startRange.location, htmlContent.length - startRange.location)];
    if (endRange.location == NSNotFound) {
        return nil;
    }
    
    // 提取包含方括号的完整字符串
    NSRange contentRange = NSMakeRange(startRange.location + 5, endRange.location - startRange.location - 4);
    return [htmlContent substringWithRange:contentRange];
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
