//
//  AppTabBarController.m
//  PicData
//
//  Created by Garenge on 2020/11/4.
//  Copyright © 2020 garenge. All rights reserved.
//
//  自定义底部 Tab Bar：继承 PDTabBarController，Tab 固定在底部，适配 Mac Catalyst。
//

#import "AppTabBarController.h"
#import "HomeViewController.h"
#import "SettingViewController.h"
#import "LocalFileListVC.h"
#import "TasksViewController.h"
#import "BaseNavigationController.h"

static void * const kKVOContext = (void *)&kKVOContext;

@interface AppTabBarController ()

@property (nonatomic, weak, nullable) UINavigationController *observedNav;

@end

@implementation AppTabBarController

#pragma mark - Lifecycle

- (void)dealloc {
    [self removeNavObserverIfNeeded];
}

#pragma mark - PDTabBarController Override

- (void)configureTabBarContent {
    [super configureTabBarContent];

    // 主页
    HomeViewController *indexVC = [[HomeViewController alloc] init];
    BaseNavigationController *indexNavi = [[BaseNavigationController alloc] initWithRootViewController:indexVC];

    // 预览
    LocalFileListVC *viewerVC = [[LocalFileListVC alloc] init];
    BaseNavigationController *viewerNavi = [[BaseNavigationController alloc] initWithRootViewController:viewerVC];

    // 下载
    TasksViewController *tasksVC = [[TasksViewController alloc] init];
    BaseNavigationController *tasksNavi = [[BaseNavigationController alloc] initWithRootViewController:tasksVC];

    // 设置
    SettingViewController *settingVC = [[SettingViewController alloc] init];
    BaseNavigationController *settingNavi = [[BaseNavigationController alloc] initWithRootViewController:settingVC];

    self.viewControllers = @[indexNavi, viewerNavi, tasksNavi, settingNavi];
    self.tabTitles = @[@"首页", @"浏览", @"下载", @"设置"];
    self.tabSymbolNames = @[@"house.fill", @"folder.fill", @"arrow.down.circle.fill", @"gearshape.fill"];
}

- (void)pd_didSwitchToIndex:(NSInteger)index {
    [self setupNavObserverForHidesBottomBar];
}

#pragma mark - Prepare (通知注册)

- (void)prepare {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNoticeOfDownloadPath:) name:NOTICECHECKDOWNLOADPATHKEY object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationThatInitHostModelsFailed:) name:NotificationNameInitHostModelsFailed object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationThatClearedAllFiles:) name:NotificationNameClearedAllFiles object:nil];
}

#pragma mark - hidesBottomBarWhenPushed（模拟系统 UITabBarController 行为）

/// 对当前选中的 Nav 监听 viewControllers 变化，根据 topVC 的 hidesBottomBarWhenPushed 决定是否隐藏 TabBar
- (void)setupNavObserverForHidesBottomBar {
    [self removeNavObserverIfNeeded];
    UIViewController *vc = self.selectedViewController;
    if (![vc isKindOfClass:[UINavigationController class]]) return;

    UINavigationController *nav = (UINavigationController *)vc;
    self.observedNav = nav;
    [nav addObserver:self forKeyPath:@"viewControllers" options:NSKeyValueObservingOptionNew context:kKVOContext];
    [self updateTabBarVisibilityForTopViewController];
}

- (void)removeNavObserverIfNeeded {
    if (!self.observedNav) return;
    @try {
        [self.observedNav removeObserver:self forKeyPath:@"viewControllers" context:kKVOContext];
    } @catch (NSException * __unused exception) {}
    self.observedNav = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == kKVOContext && [keyPath isEqualToString:@"viewControllers"]) {
        [self updateTabBarVisibilityForTopViewController];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateTabBarVisibilityForTopViewController {
    UIViewController *vc = self.selectedViewController;
    if (![vc isKindOfClass:[UINavigationController class]]) {
        [self setTabBarHidden:NO];
        return;
    }
    UINavigationController *nav = (UINavigationController *)vc;
    UIViewController *top = nav.topViewController;
    [self setTabBarHidden:top ? top.hidesBottomBarWhenPushed : NO];
}

#pragma mark - Notifications

- (void)receiveNoticeOfDownloadPath:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showAlertWithTitle:@"提醒" message:@"下载路径设置有误, 请确认地址" confirmTitle:@"去设置" confirmHandler:^(UIAlertAction * _Nonnull action) {
            [self setSelectedIndex:3];
        } cancelTitle:@"稍后" cancelHandler:nil];
    });
}

- (void)notificationThatInitHostModelsFailed:(NSNotification *)notification {
    [self showAlertWithTitle:nil message:@"初始化域名模组失败, 无法使用APP" confirmTitle:@"退出" confirmHandler:^(UIAlertAction * _Nonnull action) {
        abort();
    }];
}

- (void)notificationThatClearedAllFiles:(NSNotification *)notification {
    if (self.viewControllers.count > 1 && [self.viewControllers[1] isKindOfClass:[UINavigationController class]]) {
        BaseNavigationController *navi = self.viewControllers[1];
        [navi popToRootViewControllerAnimated:YES];
    }
}

@end
