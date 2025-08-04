//
//  UILabel+ppEx.h
//  PPToolKit
//
//  Created by Garenge on 2025/7/13.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UILabel (ppEx)

+ (instancetype)pp_labelWithText:(nullable NSString *)text textColor:(UIColor *)textColor font:(UIFont *)font;
+ (instancetype)pp_labelWithText:(nullable NSString *)text textColor:(UIColor *)textColor font:(UIFont *)font alignment:(NSTextAlignment)alignment;

@end

NS_ASSUME_NONNULL_END
