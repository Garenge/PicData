//
//  AppTabBarController.h
//  PicData
//
//  Created by Garenge on 2020/11/4.
//  Copyright © 2020 garenge. All rights reserved.
//
//  自定义底部 Tab Bar 控制器，继承 PDTabBarController，Tab 固定显示在底部，适配 Mac Catalyst。
//

#import "PDTabBarController.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppTabBarController : PDTabBarController

/// 初始化并注册通知等，在设为 rootViewController 之前调用
- (void)prepare;

@end

NS_ASSUME_NONNULL_END
