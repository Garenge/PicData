//
//  UILabel+ppEx.m
//  PPToolKit
//
//  Created by Garenge on 2025/7/13.
//

#import "UILabel+ppEx.h"

@implementation UILabel (ppEx)

+ (instancetype)pp_labelWithText:(NSString *)text textColor:(UIColor *)textColor font:(UIFont *)font {
    return [self pp_labelWithText:text textColor:textColor font:font alignment:NSTextAlignmentLeft];
}
+ (instancetype)pp_labelWithText:(NSString *)text textColor:(UIColor *)textColor font:(UIFont *)font alignment:(NSTextAlignment)alignment {
    UILabel *label = [[self alloc] init];
    label.text = text;
    label.textColor = textColor;
    label.font = font;
    label.textAlignment = alignment;
    return label;
}

@end
