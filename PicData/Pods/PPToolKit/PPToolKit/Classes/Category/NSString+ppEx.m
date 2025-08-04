//
//  NSString+ppEx.m
//  PicData
//
//  Created by 鹏鹏 on 2022/8/22.
//  Copyright © 2022 garenge. All rights reserved.
//

#import "NSString+ppEx.h"

@implementation NSString (ppEx)

/// 格式化文件大小, 将字节大小转换为合适的单位
+ (NSString *)pp_fileSizeFormat:(long long)value
{
    if (value < 0) {
        return @"0B";
    }

    NSString *sizeString = @"";

    NSArray *formatArray = @[@"B", @"KB", @"MB", @"GB", @"TB", @"PB"];
    NSInteger count = formatArray.count;

    NSInteger index = 0;
    double size = value;
    while (index < count && size >= 1024) {
        size = size / 1024;
        index ++;
    }

    // 输出当前 格式
    if (index == 0) {
        sizeString = [NSString stringWithFormat:@"%d%@", (int)size, formatArray[index]];
    } else {
        sizeString = [NSString stringWithFormat:@"%@%@", [self pp_removeFloatAllZeroByString:[NSString stringWithFormat:@"%.2f", size]], formatArray[index]];
    }

    return sizeString;
}

+ (NSString*)pp_removeFloatAllZeroByString:(NSString *)testNumber{
    NSString * outNumber = [NSString stringWithFormat:@"%@",@(testNumber.floatValue)];
    return outNumber;
}

/// 获取字符串长度
NSInteger NSStringLengthOfString(NSString *string) {
    if (string == nil) {
        return 0;
    } else if (![string isKindOfClass:[NSString class]]) {
        return 0;
    }
    return string.length;
}

/// 生成字符串
NSString * NSStringFromInteger(NSInteger integer) {
    return [NSString stringWithFormat:@"%ld", integer];
}

- (NSString *)trimLeft {
    if (!NSStringLengthOfString(self)) {
        return @"";
    }
    
    NSUInteger len = 0;
    
    while (len < self.length) {
        if ([self characterAtIndex:len] != ' ') {
            break;
        }
        
        len++;
    }
    
    if (len >= self.length) {
        len = self.length - 1;
    }
    
    return [self substringFromIndex:len];
}

- (NSString *)trimRight {
    if (!NSStringLengthOfString(self)) {
        return @"";
    }
    
    NSInteger index = self.length - 1;
    for (NSInteger i = self.length - 1; i >= 0; --i) {
        if ([self characterAtIndex:i] != ' ') {
            break;
        } else {
            index--;
        }
    }
    
    if (index + 1 < self.length) {
        index++;
    }
    
    if (index + 1 >= self.length) {
        return self;
    }
    
    return [self substringToIndex:index];
}

- (NSString *)trim {
    if (self.length==0) {
        return self;
    }else{
        NSCharacterSet  *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        return [self stringByTrimmingCharactersInSet:set];
    }
}

- (NSString *)trimAll {
    return [self stringByReplacingOccurrencesOfString:@" " withString:@""];
}

/// 判断是否是数字, 可以是整数, 小数, 负数
+ (BOOL)isValidNumber:(NSString *)string {
    if (NSStringLengthOfString(string) == 0) {
        return NO;
    }
    NSString *pattern = @"^-?[0-9]+(\\.[0-9]+)?$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSUInteger matches = [regex numberOfMatchesInString:string options:0 range:NSMakeRange(0, string.length)];
    return matches > 0;
}

/// 判断字符串长度, 如果为0, 则 使用替换值
NSString * NSStringReplaceIfEmpty(NSString * _Nullable string, NSString * _Nullable replaceString) {
    if (nil == string) {
        return replaceString;
    }
    if ([string isKindOfClass:[NSNull class]]) {
        return replaceString;
    }
    string = [NSString stringWithFormat:@"%@", string];
    if (NSStringLengthOfString(string) == 0) {
        return replaceString;
    }
    return string;
}

/// 比对版本号大小, 只能传入数字和点
+ (NSComparisonResult)compareCurrentVersion:(NSString *)currentVersion newVersion:(NSString *)newVersion
{
    NSArray *currentVersionArray = [currentVersion componentsSeparatedByString:@"."];
    NSArray *newVersionArray = [newVersion componentsSeparatedByString:@"."];
    
    // 1.0.0 -> 1.0.1
    // 2.0 -> 1.9.9
    
    NSInteger count = MAX(currentVersionArray.count, newVersionArray.count);
    for (NSInteger i = 0; i < count; i++) {
        NSInteger current = 0;
        NSInteger new = 0;
        
        if (i < currentVersionArray.count) {
            current = [currentVersionArray[i] integerValue];
        }
        
        if (i < newVersionArray.count) {
            new = [newVersionArray[i] integerValue];
        }
        
        if (current > new) {
            return NSOrderedDescending;
        } else if (current < new) {
            return NSOrderedAscending;
        }
    }
    
    return NSOrderedSame;
}

/// 获取字符串的精度位数, 方便计算, 比如0.1, 返回1, 0.001, 返回3, 如果是其他的, 返回0
- (NSInteger)getPrecisionAccuracyCount {
    if (nil == self || self.length == 0) {
        return 0;
    }
    
    // !!!!!!! 涉及到多种不确定因素和特殊字符串, 考虑到实际业务, 没必要写一个复杂到爆的算法判断
    // 直接判断
    NSDictionary *dict = @{@"0.1":@(1),
                           @"0.01":@(2),
                           @"0.001":@(3),
                           @"0.0001":@(4),
                           @"0.00001":@(5),
                           @"0.000001":@(6),
                           @"0.0000001":@(7),
                           @"0.00000001":@(8),
                           @"0.000000001":@(9),
    };
    NSNumber *accuracyCount = dict[self];
    if (accuracyCount) {
        return accuracyCount.integerValue;
    }
    return 0;
}

/// 获取字符串表示的精度, 方便计算, 排除异常值, 比如0.1就是0.1, 0.001就是0.001, 但是特殊值返回1.0, 0.12啥的也当做异常处理
- (CGFloat)getPrecisionAccuracyScale {
    //    if (nil == self || self.length == 0) {
    //        return 1.0;
    //    }
    //
    //    // !!!!!!! 涉及到多种不确定因素和特殊字符串, 考虑到实际业务, 没必要写一个复杂到爆的算法判断
    //    // 直接判断
    //    NSDictionary *dict = @{@"1": @(1),
    //                           @"1": @(1),
    //                           @"1": @(1),
    //                           @"0.1": @(0.1),
    //                           @"0.01": @(0.01),
    //                           @"0.001": @(0.001),
    //                           @"0.0001": @(0.0001),
    //                           @"0.00001": @(0.00001),
    //                           @"0.000001": @(0.000001),
    //                           @"0.0000001": @(0.0000001),
    //                           @"0.00000001": @(0.00000001),
    //                           @"0.000000001": @(0.000000001),
    //    };
    //    NSNumber *accuracyCount = dict[[NSString stringWithFormat:@"%f", self.doubleValue]];
    //    if (accuracyCount.doubleValue > 0) {
    //        return accuracyCount.doubleValue;
    //    }
    //    return 1.0;
    return [self doubleValue] > 0 ? [self doubleValue] : 1.0;
}

- (NSArray <NSValue *>*)getRangesOfSplitStringsWithLeadingString:(NSString *)leadingString trailingString:(NSString *)trailingString error:(NSError **)error {
    NSString *regex = [NSString stringWithFormat:@"(?<=(%@)).*?(?=(%@))", leadingString, trailingString];
    NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:error];
    // 对str字符串进行匹配
    NSMutableArray *array = [NSMutableArray array];
    for (NSTextCheckingResult *match in [regular matchesInString:self options:0 range:NSMakeRange(0, self.length)]) {
        [array addObject:[NSValue valueWithRange:match.range]];
    }
    return array;
}

#pragma mark - 文件处理

/// 文件大小格式化
+ (NSString *)fileSizeFormat:(long long)value
{
    if (value < 0) {
        return @"0B";
    }
    
    NSString *sizeString = @"";
    
    NSArray *formatArray = @[@"B", @"KB", @"MB", @"GB", @"TB", @"PB"];
    NSInteger count = formatArray.count;
    
    NSInteger index = 0;
    double size = value;
    while (index < count && size >= 1024) {
        size = size / 1024;
        index ++;
    }
    
    // 输出当前 格式
    if (index == 0) {
        sizeString = [NSString stringWithFormat:@"%d%@", (int)size, formatArray[index]];
    } else {
        sizeString = [NSString stringWithFormat:@"%@%@", [self removeFloatAllZeroByString:[NSString stringWithFormat:@"%.2f", size]], formatArray[index]];
    }
    
    return sizeString;
}

/// 移除数字的多余小数, 比如3.3000, 其实就是3.3
+ (NSString*)removeFloatAllZeroByString:(NSString *)testNumber{
    NSString * outNumber = [NSString stringWithFormat:@"%@",@(testNumber.doubleValue)];
    return outNumber;
}

/// 生成随机文件名
/// - Parameter pathExtension: 提供文件后缀名, 只要点后面的字符串
+ (NSString *)getRandomFileNameWithPathExtension:(NSString *)pathExtension {
    return [NSString getRandomFileNameWithPathExtension:pathExtension timeformat:@"yyyyMMddHHmmssSSS" randomNumCount:4];
}

/// 生成随机文件名 - 按格式
/// - Parameters:
///   - pathExtension: 提供文件后缀名, 只要点后面的字符串
///   - timeformat: 时间格式, 比如 yyyyMMddHHmmssSSS
///   - randomNumCount: 补充整数的位数, 比如自动补充四位整数
+ (NSString *)getRandomFileNameWithPathExtension:(NSString *)pathExtension timeformat:(NSString *)timeformat randomNumCount:(NSInteger)randomNumCount {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = timeformat;
    NSString *timeString = [dateFormatter stringFromDate:[NSDate date]];
    NSString *inteFormat = [NSString stringWithFormat:@"%%%ldld", randomNumCount];
    NSString *format = [NSString stringWithFormat:@"%%@%@", inteFormat];
    NSString *fileName = [NSString stringWithFormat:format, timeString, arc4random() % (long)pow(10, randomNumCount)];
    if (pathExtension.length > 0) {
        fileName = [fileName stringByAppendingPathExtension:pathExtension];
    }
    return fileName;
}

#pragma mark - 美化输出字典


/// 美化json输出, 为了打印美观
/// - Parameter jsonObject: 可以是字典, 可以是data对象
+ (NSString *)prettyWithJsonObject:(id)preObject {
    
    return [self prettyWithJsonObject:preObject error:nil];
}

+ (NSString *)prettyWithJsonObject:(id)preObject error:(NSError *__autoreleasing *)error {
    
    if (nil == preObject) { return nil; }
    
    // 如果是data, 转成一般的json
    NSObject *jsonObject;
    
    if ([preObject isKindOfClass:[NSString class]]) {
        jsonObject = [preObject dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    if ([preObject isKindOfClass:[NSData class]]) {
        
        if (((NSData *)preObject).length == 0) { return nil; }
        
        jsonObject = [NSJSONSerialization JSONObjectWithData:preObject options:NSJSONReadingMutableContainers error:error];
        
        // 这个地方要注意, error是指针的指针, 所以要判断error是否为空, 以及jsonObject是否为空
        if (*error != NULL || jsonObject == nil) { return nil; }
        
    } else if ([preObject isKindOfClass:[NSArray class]] || [preObject isKindOfClass:[NSDictionary class]]) {
        jsonObject = preObject;
    } else {
        return nil;
    }
    
    NSData *printData = [NSJSONSerialization dataWithJSONObject:jsonObject options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted | NSJSONWritingWithoutEscapingSlashes error:error];
    if (nil == printData || printData.length == 0) {
        return nil;
    }
    
    NSString *result = [[NSString alloc]initWithData:printData encoding:NSUTF8StringEncoding];
    return result;
}

#pragma mark - 编码

/// 字符串 url编码
- (NSString *)stringByAddingPercentEncodingWithURLQueryAllowedCharacterSet {
    return [self stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}

@end

@implementation NSURL (Extension)

+ (nullable NSURL *)URLWithStringByAddingPercentEncodingWithURLQueryAllowedCharacterSet:(NSString *_Nullable)string {
    return [NSURL URLWithString:[string stringByAddingPercentEncodingWithURLQueryAllowedCharacterSet]];
}

@end
