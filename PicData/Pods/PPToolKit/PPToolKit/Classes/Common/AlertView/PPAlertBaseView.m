//
//  PPAlertBaseView.m
//  PPToolKit
//
//  Created by pengpeng on 2023/6/15.
//  Copyright © 2023 Falcon Automation. All rights reserved.
//

#import "PPAlertBaseView.h"
#import "Config.h"

@implementation PPAlertAction

+ (instancetype)actionWithTitle:(NSString *)title {
    PPAlertAction *action = [PPAlertAction new];
    action.title = title;
    return action;
}

+ (instancetype)actionWithTitle:(NSString *)title actionBlock:(nullable PPAlertActionBlock)actionBlock {
    PPAlertAction *action = [PPAlertAction new];
    action.title = title;
    action.actionBlock = actionBlock;
    return action;
}

+ (nonnull instancetype)actionWithTitle:(nonnull NSString *)title type:(PPAlertActionType)type actionBlock:(nullable PPAlertActionBlock)actionBlock {
    PPAlertAction *action = [PPAlertAction new];
    action.title = title;
    action.type = type;
    action.actionBlock = actionBlock;
    return action;
}

@end

@interface PPAlertBaseView() <UIGestureRecognizerDelegate>

@end

@implementation PPAlertBaseView

- (void)dealloc {
    NSLog(@"======== YDHAlertBGView dealloc ========");
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {

        [self setupSubView];
    }
    return self;
}

- (void)setupSubView {
    self.backgroundColor = rgba(0, 0, 0, 0.5);
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapViewAction:)];
    tap.delegate = self;
    [self addGestureRecognizer:tap];
}

- (void)show {
    [self showWithAnimate:YES];
}
- (void)showWithAnimate:(BOOL)animate {

    if (animate) {
        self.alpha = 0;
    }

    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    self.frame = window.bounds;
    [window addSubview:self];
    [self layoutIfNeeded];

    if (animate) {
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 1;
        }];
    }
}

- (void)dismiss {
    [self dismissWithAnimate:YES];
}

- (void)dismissWithAnimate:(BOOL)animate {

    if (animate) {
        [UIView animateWithDuration:0.3 animations:^{
            self.alpha = 0;
        } completion:^(BOOL finished) {
            [self removeFromSuperview];
        }];
    } else {
        [self removeFromSuperview];
    }
}

#pragma mark - action

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint location = [gestureRecognizer locationInView:self];
    for (UIView *subview in self.subviews) {
        if (CGRectContainsPoint(subview.frame, location)) {
            return NO;
        }
    }
    return YES;
}

- (void)tapViewAction:(UITapGestureRecognizer *)sender {

    if (nil == self.touchEmptyAreaBlock) {
        return;
    }

    self.touchEmptyAreaBlock(self);
}

@end
