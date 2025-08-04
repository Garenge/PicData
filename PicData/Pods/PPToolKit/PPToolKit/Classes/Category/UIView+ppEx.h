//
//  UIView+ppEx.h
//  PPToolKit
//
//  Created by Garenge on 2025/1/4.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (ppEx)

+ (instancetype)pp_view;
+ (instancetype)pp_viewWithBackgroundColor:(UIColor *)color;

@property (nonatomic, assign) CGFloat pp_width;
@property (nonatomic, assign) CGFloat pp_height;

@property (nonatomic, assign) CGFloat borderCornerRadius;
- (void)setBorderCornerRadius:(CGFloat)borderCornerRadius borderColor:(UIColor *)color width:(CGFloat)width;

@end

@interface UIStackView (ppEx)

- (instancetype)initWithAxis:(UILayoutConstraintAxis)axis;
+ (instancetype)pp_viewWithAxis:(UILayoutConstraintAxis)axis;

@end

NS_ASSUME_NONNULL_END
