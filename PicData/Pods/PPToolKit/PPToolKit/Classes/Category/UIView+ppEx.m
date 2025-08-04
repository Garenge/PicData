//
//  UIView+ppEx.m
//  PPToolKit
//
//  Created by Garenge on 2025/1/4.
//

#import "UIView+ppEx.h"

@implementation UIView (ppEx)

+ (instancetype)pp_view {
    return [[self alloc] init];
}

+ (instancetype)pp_viewWithBackgroundColor:(UIColor *)color {
    UIView *view = [self pp_view];
    view.backgroundColor = color;
    return view;
}

- (CGFloat)pp_width {
    return self.frame.size.width;
}

- (void)setPp_width:(CGFloat)pp_width {
    CGRect frame = self.frame;
    frame.size.width = pp_width;
    self.frame = frame;
}

- (CGFloat)pp_height {
    return self.frame.size.height;
}

- (void)setPp_height:(CGFloat)pp_height {
    CGRect frame = self.frame;
    frame.size.height = pp_height;
    self.frame = frame;
}

- (CGFloat)borderCornerRadius {
    return self.layer.cornerRadius;
}

- (void)setBorderCornerRadius:(CGFloat)borderCornerRadius {
    self.layer.cornerRadius = borderCornerRadius;
    self.layer.masksToBounds = YES;
}

- (void)setBorderCornerRadius:(CGFloat)borderCornerRadius borderColor:(UIColor *)color width:(CGFloat)width {
    self.borderCornerRadius = borderCornerRadius;
    self.layer.borderColor = color.CGColor;
    self.layer.borderWidth = width;
}

@end

@implementation UIStackView (ppEx)

- (instancetype)initWithAxis:(UILayoutConstraintAxis)axis {
    if (self = [self init]) {
        self.axis = axis;
        self.distribution = UIStackViewDistributionFill;
    }
    return self;
}
+ (instancetype)pp_viewWithAxis:(UILayoutConstraintAxis)axis {
    return [[self alloc] initWithAxis:axis];
}

@end
