//
//  NSString+ppEx.h
//  PicData
//
//  Created by 鹏鹏 on 2022/8/22.
//  Copyright © 2022 garenge. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (ppEx)

/// 格式化文件大小, 将字节大小转换为合适的单位
+ (NSString *)pp_fileSizeFormat:(long long)value;

/// 获取字符串长度
NSInteger NSStringLengthOfString(NSString *string);
/// 生成字符串
NSString * NSStringFromInteger(NSInteger integer);
/**
 去掉字符串左边的所有空格
 
 @return 修正后的字符串
 */
- (NSString *)trimLeft;

/**
 去掉字符串右边的所有空格
 
 @return 修正后的字符串
 */
- (NSString *)trimRight;

/**
 去掉字符串左边和右边的空格
 
 @return 修正后的字符串
 */
- (NSString *)trim;

/**
 去掉字符串里面所有空格
 
 @return 修正后的字符串
 */
- (NSString *)trimAll;

/// 判断是否是数字, 可以是整数, 小数, 负数
+ (BOOL)isValidNumber:(NSString *)string;

/// 判断字符串长度, 如果为0, 则 使用替换值
NSString * NSStringReplaceIfEmpty(NSString * _Nullable string, NSString * _Nullable replaceString);

/// 比对版本号大小, 只能传入数字和点
+ (NSComparisonResult)compareCurrentVersion:(NSString *)currentVersion newVersion:(NSString *)newVersion;

/// 获取字符串的精度位数, 方便计算, 比如0.1, 返回1, 0.001, 返回3, 如果是其他的, 返回0
- (NSInteger)getPrecisionAccuracyCount;
/// 获取字符串表示的精度, 方便计算, 排除异常值, 比如0.1就是0.1, 0.001就是0.001, 但是特殊值返回1.0, 0.12啥的也当做异常处理
- (CGFloat)getPrecisionAccuracyScale;

/// 传参两边的字符串, 返回中间字符串的range数组
- (NSArray <NSValue *>*)getRangesOfSplitStringsWithLeadingString:(NSString *)leadingString trailingString:(NSString *)trailingString error:(NSError **)error;

#pragma mark - 文件处理

/// 文件大小格式化
+ (NSString *)fileSizeFormat:(long long)value;

/// 移除数字的多余小数, 比如3.3000, 其实就是3.3
+ (NSString*)removeFloatAllZeroByString:(NSString *)testNumber;

/// 生成随机文件名
/// - Parameter pathExtension: 提供文件后缀名, 只要点后面的字符串
+ (NSString *)getRandomFileNameWithPathExtension:(NSString *)pathExtension;

/// 生成随机文件名 - 按格式
/// - Parameters:
///   - pathExtension: 提供文件后缀名, 只要点后面的字符串
///   - timeformat: 时间格式, 比如 yyyyMMddHHmmssSSS
///   - randomNumCount: 补充整数的位数, 比如自动补充四位整数
+ (NSString *)getRandomFileNameWithPathExtension:(NSString *)pathExtension timeformat:(NSString *)timeformat randomNumCount:(NSInteger)randomNumCount;

#pragma mark - 美化输出字典


/// 美化json输出, 为了打印美观
/// - Parameter jsonObject: 可以是字典, 可以是data对象
+ (nullable NSString *)prettyWithJsonObject:(id _Nullable )preObject;
+ (nullable NSString *)prettyWithJsonObject:(id _Nullable )preObject error:(NSError **)error;

#pragma mark - 编码

/// 字符串 url编码 URLQueryAllowedCharacterSet
- (nullable NSString *)stringByAddingPercentEncodingWithURLQueryAllowedCharacterSet;

@end

@interface NSURL (Extension)

+ (nullable NSURL *)URLWithStringByAddingPercentEncodingWithURLQueryAllowedCharacterSet:(NSString *_Nullable)string;

@end

NS_ASSUME_NONNULL_END
