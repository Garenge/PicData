//
//  UIButton+ppEx.h
//  PPToolKit
//
//  Created by Garenge on 2025/6/29.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIButton (ppEx)

@property (nonatomic, strong) UIFont *titleFont;

+ (instancetype)pp_buttonWithTitle:(NSString *)title titleColor:(UIColor *)titleColor titleFont:(UIFont *)titleFont;

@end

NS_ASSUME_NONNULL_END
