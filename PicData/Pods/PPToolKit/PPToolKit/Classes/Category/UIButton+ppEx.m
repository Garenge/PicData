//
//  UIButton+ppEx.m
//  PPToolKit
//
//  Created by Garenge on 2025/6/29.
//

#import "UIButton+ppEx.h"

@implementation UIButton (ppEx)

- (void)setTitleFont:(UIFont *)titleFont {
    self.titleLabel.font = titleFont;
}

- (UIFont *)titleFont {
    return self.titleLabel.font;
}

+ (instancetype)pp_buttonWithTitle:(NSString *)title titleColor:(UIColor *)titleColor titleFont:(UIFont *)titleFont {
    UIButton *button = [self buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:titleColor forState:UIControlStateNormal];
    button.titleLabel.font = titleFont;
    return button;
}

@end
