//
//  NSObject+ppEx.m
//  PPToolKit
//
//  Created by Garenge on 2025/7/18.
//

#import "NSObject+ppEx.h"

@implementation NSObject (ppEx)

@end

@implementation NSJSONSerialization (HEEx)

/// 从文件里面直接拿到json, 可为空
+ (nullable id)getJsonFromFileWithFilePath:(NSString *)filePath {
    if (nil == filePath || filePath.length == 0) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    NSObject *json = [self getJsonFromData:data];
    return json;
}

/// 从字符串里面直接拿到json, 可为空
+ (nullable id)getJsonFromString:(nullable NSString *)string {
    if (nil == string || string.length == 0) {
        return nil;
    }
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSObject *json = [self getJsonFromData:data];
    return json;
}

/// 从data里面直接拿到json, 可为空
+ (nullable id)getJsonFromData:(nullable NSData *)data {
    if (nil == data || data.length == 0) {
        return nil;
    }
    NSError *readError = nil;
    NSObject *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&readError];
    return json;
}

/// 将json转换成字符串
+ (NSString *)getStringFromJson:(id)json {
    if(nil == json) {
        return nil;
    }
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingWithoutEscapingSlashes error:&error];
    if (error) {
        return nil;
    }
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return jsonString;
}

/// 将json转换成字符串
+ (nullable NSString *)getPrettyStringFromJson:(id)json {
    if(nil == json) {
        return nil;
    }
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted | NSJSONWritingWithoutEscapingSlashes error:&error];
    if (error) {
        return nil;
    }
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return jsonString;
}

@end
