//
//  ContentParserManager+Parser.m
//  PicData
//
//  Created by 鹏鹏 on 2022/5/28.
//  Copyright © 2022 garenge. All rights reserved.
//

#import "ContentParserManager+Parser.h"
#import "ContentParserFactory.h"
#import "AppTool.h"

@implementation ContentParserManager (Parser)

+ (NSString *)getHtmlStringWithData:(NSData *)data sourceType:(int)sourceType {
    id<ContentParserProtocol> parser = [ContentParserFactory parserForSourceType:sourceType];
    if (parser && [parser respondsToSelector:@selector(getHtmlStringWithData:)]) {
        return [parser getHtmlStringWithData:data];
    }
    return @"";
}

#pragma mark - 开始处理, 获取套图数组
/// 开放接口, 获取套图数组, 以及下一页等
+ (void)parseContentListWithHtmlString:(NSString *)htmlString 
                           sourceModel:(nonnull PicSourceModel *)sourceModel 
                       completeHandler:(void(^)(NSArray <PicContentModel *>* _Nonnull contentList, NSURL * _Nullable nextPageURL))completeHandler {

    if (htmlString.length == 0) {
        PPIsBlockExecute(completeHandler, @[], nil);
        return;
    }
    
    OCGumboDocument *document = [[OCGumboDocument alloc] initWithHTMLString:htmlString];

    // 获取对应的解析器
    id<ContentParserProtocol> parser = [ContentParserFactory parserForSourceType:sourceModel.sourceType];
    if (!parser) {
        PPIsBlockExecute(completeHandler, @[], nil);
        return;
    }

    // 获取套图数组
    NSArray *results = [parser parseContentListWithDocument:document sourceModel:sourceModel];

    // 获取下一页链接
    NSString *nextPage = [parser parseNextPageWithDocument:document sourceModel:sourceModel];
    NSURL *nextPageURL = nil;
    
    if (nextPage.length > 0) {
        nextPageURL = [NSURL URLWithString:nextPage relativeToURL:[NSURL URLWithString:sourceModel.HOST_URL]];
    }

    PPIsBlockExecute(completeHandler, results, nextPageURL);
}

/// 获取套图列表
+ (NSArray<PicContentModel *> *)parseContentListWithDocument:(OCGumboDocument *)document 
                                                 sourceModel:(PicSourceModel *)sourceModel {
    id<ContentParserProtocol> parser = [ContentParserFactory parserForSourceType:sourceModel.sourceType];
    if (!parser) {
        return @[];
    }
    
    return [parser parseContentListWithDocument:document sourceModel:sourceModel];
}

#pragma mark 获取单个套图的信息
/// 获取单个套图的信息
+ (PicContentModel *)getContentModelWithSourceModel:(PicSourceModel *)sourceModel 
                                withArticleElement:(OCGumboElement *)articleElement {
    id<ContentParserProtocol> parser = [ContentParserFactory parserForSourceType:sourceModel.sourceType];
    if (!parser) {
        return nil;
    }
    
    return [parser getContentModelWithArticleElement:articleElement sourceModel:sourceModel];
}

#pragma mark 开始解析网页详情数据
/// 开始解析网页详情数据
+ (void)parseDetailWithHtmlString:(NSString *)htmlString 
                             href:(NSString *)href 
                       sourceModel:(PicSourceModel *)sourceModel 
                       preNextUrl:(NSString *)preNextUrl 
                       needSuggest:(BOOL)needSuggest 
                   completeHandler:(void (^)(NSArray<NSString *> * _Nonnull, NSString * _Nonnull, NSArray<PicContentModel *> * _Nullable, NSString * _Nullable))completeHandler {

    if (htmlString.length == 0) {
        PPIsBlockExecute(completeHandler, @[], @"", @[], @"");
        return;
    }

    OCGumboDocument *document = [[OCGumboDocument alloc] initWithHTMLString:htmlString];

    // 获取对应的解析器
    id<ContentParserProtocol> parser = [ContentParserFactory parserForSourceType:sourceModel.sourceType];
    if (!parser) {
        PPIsBlockExecute(completeHandler, @[], @"", @[], @"");
        return;
    }

    // 解析详情页图片
    NSArray<NSString *> *urls = [parser parseDetailImagesWithDocument:document sourceModel:sourceModel];
    
    // 解析下一页链接
    NSString *nextPage = [parser parseNextPageWithDocument:document sourceModel:sourceModel] ?: @"";
    
    // 解析推荐内容
    NSArray<PicContentModel *> *suggestions = @[];
    if (needSuggest) {
        suggestions = [parser parseSuggestionsWithDocument:document sourceModel:sourceModel];
    }
    
    // 解析页面标题
    NSString *contentTitle = [parser parsePageTitleWithDocument:document href:href sourceModel:sourceModel];

    PPIsBlockExecute(completeHandler, urls, nextPage, suggestions, contentTitle);
}

#pragma mark tag, 标签数据

/// 解析tag标签页, 获取tag数组
+ (NSArray <PicClassModel *>*)parseTagsWithHtmlString:(NSString *)htmlString 
                                            HostModel:(PicNetModel *)hostModel {
    if (htmlString.length == 0) {
        return @[];
    }

    OCGumboDocument *document = [[OCGumboDocument alloc] initWithHTMLString:htmlString];
    
    id<ContentParserProtocol> parser = [ContentParserFactory parserForSourceType:hostModel.sourceType];
    if (!parser) {
        return @[];
    }
    
    return [parser parseTagsWithDocument:document hostModel:hostModel];
}

/// 获取分类, tag页面模型数据
+ (PicClassModel *)getClassModelWithHostModel:(PicNetModel *)hostModel 
                           withTagsListElement:(OCGumboElement *)tagsListE {
    // 这个方法现在由具体的解析器实现
    // 保留作为兼容性接口
    return nil;
}

/// 获取套图的title
+ (NSString *)parsePageForTitleWithDocument:(OCGumboDocument *)document 
                                       href:(NSString *)href 
                                 sourceModel:(PicSourceModel *)sourceModel {
    id<ContentParserProtocol> parser = [ContentParserFactory parserForSourceType:sourceModel.sourceType];
    if (!parser) {
        return @"";
    }
    
    return [parser parsePageTitleWithDocument:document href:href sourceModel:sourceModel];
}

/// 封装补充随机名称的代码
+ (NSString *)updateCustomContentName:(NSString *)preContentTitle 
                          contentHref:(NSString *)contentHref 
                          sourceModel:(PicSourceModel *)sourceModel {
    // 这个方法现在由具体的解析器实现
    // 保留作为兼容性接口
    return preContentTitle;
}

/// 解析网页获取网页title
+ (NSString *)parsePageForTitle:(NSString *)htmlString 
                           href:(NSString *)href 
                     sourceModel:(PicSourceModel *)sourceModel {
    if (htmlString.length == 0) {
        return @"";
    }

    OCGumboDocument *document = [[OCGumboDocument alloc] initWithHTMLString:htmlString];
    return [self parsePageForTitleWithDocument:document href:href sourceModel:sourceModel];
}

@end
