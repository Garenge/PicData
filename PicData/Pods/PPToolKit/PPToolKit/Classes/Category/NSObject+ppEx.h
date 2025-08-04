//
//  NSObject+ppEx.h
//  PPToolKit
//
//  Created by Garenge on 2025/7/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (ppEx)

@end

@interface NSJSONSerialization (HEEx)

/// 从文件里面直接拿到json, 可为空
+ (nullable id)getJsonFromFileWithFilePath:(NSString *)filePath;
/// 从字符串里面直接拿到json, 可为空
+ (nullable id)getJsonFromString:(nullable NSString *)string;
/// 从data里面直接拿到json, 可为空
+ (nullable id)getJsonFromData:(nullable NSData *)data;

/// 将json转换成字符串
+ (nullable NSString *)getStringFromJson:(id)json;
/// 将json转换成字符串
+ (nullable NSString *)getPrettyStringFromJson:(id)json;

@end

NS_ASSUME_NONNULL_END
