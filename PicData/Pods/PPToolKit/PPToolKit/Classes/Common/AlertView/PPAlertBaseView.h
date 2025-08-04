//
//  PPAlertBaseView.h
//  PPToolKit
//
//  Created by pengpeng on 2023/6/15.
//  Copyright © 2023 Falcon Automation. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPAlertAction;
typedef void(^PPAlertActionBlock)(PPAlertAction *action);


typedef NS_ENUM(NSInteger, PPAlertActionType) {
    PPAlertActionTypeDefault = 0, // 按钮可以蓝色,粗体
    PPAlertActionTypeCancel = 1, // 普通字体
    PPAlertActionTypeDestructive = 2, // 红色粗体
    PPAlertActionTypeNotDismiss = 99, // 按钮可以蓝色,粗体, 点击不自动隐藏
    PPAlertActionTypeCancelNotDismiss = 999,// 普通字体
};

@interface PPAlertAction : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subTitle;
@property (nonatomic, strong) UIImage *image;
/// 执行方法block
@property (nonatomic, copy, nullable) PPAlertActionBlock actionBlock;

/// 专为alert提供的类型 0. 普通 1. 取消
@property (nonatomic, assign) PPAlertActionType type;



/// 根据事件title初始化
+ (instancetype)actionWithTitle:(NSString *)title;
/// 根据事件block初始化
+ (instancetype)actionWithTitle:(NSString *)title  actionBlock:(nullable PPAlertActionBlock)actionBlock;
/// 根据alert按钮样式和事件block初始化
+ (instancetype)actionWithTitle:(NSString *)title
                           type:(PPAlertActionType)type
                    actionBlock:(nullable PPAlertActionBlock)actionBlock;

@end

@interface PPAlertBaseView : UIView

///给alert加标识
@property(nonatomic,strong)NSString *identifier;

/// 默认有动画
- (void)show;
- (void)showWithAnimate:(BOOL)animate;

/// 点击了空白处
@property (nonatomic, copy) void(^touchEmptyAreaBlock)(PPAlertBaseView *alertView);
- (void)dismiss;
- (void)dismissWithAnimate:(BOOL)animate;

@end

NS_ASSUME_NONNULL_END
