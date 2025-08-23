//
//  ContentParserFactory.m
//  PicData
//
//  Created by 鹏鹏 on 2022/5/28.
//  Copyright © 2022 garenge. All rights reserved.
//

#import "ContentParserFactory.h"
#import "BaseContentParser.h"
#import "SourceType3Parser.h"
#import "SourceType4Parser.h"
#import "SourceType5Parser.h"
#import "SourceType10Parser.h"

@implementation ContentParserFactory

+ (nullable id<ContentParserProtocol>)parserForSourceType:(int)sourceType {
    switch (sourceType) {
        case 3:
            return [[SourceType3Parser alloc] init];
        case 4:
            return [[SourceType4Parser alloc] init];
        case 5:
            return [[SourceType5Parser alloc] init];
        case 10:
            return [[SourceType10Parser alloc] init];
        default:
            return nil;
    }
}

+ (NSArray<NSNumber *> *)supportedSourceTypes {
    return @[@3, @4, @5, @10];
}

@end 