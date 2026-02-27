//
//  PDTabBarController.h
//  PicData
//
//  自定义底部 Tab 容器基类，对外可复用。项目中的具体 Tab 根控制器应继承此类，
//  在 -configureTabBarContent 中设置 viewControllers / tabTitles / tabSymbolNames。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PDTabBarController : UIViewController

/// 当前选中的 Tab 索引（只读，供外部查询）
@property (nonatomic, assign, readonly) NSInteger selectedIndex;

/// 当前选中的子视图控制器（只读）
@property (nonatomic, readonly, nullable) UIViewController *selectedViewController;

/// 子类在 -configureTabBarContent 中赋值：要展示的 VC 列表（与 tab 顺序一致）
@property (nonatomic, copy) NSArray<UIViewController *> *viewControllers;
/// 子类在 -configureTabBarContent 中赋值：每个 Tab 的标题，与 viewControllers 一一对应
@property (nonatomic, copy) NSArray<NSString *> *tabTitles;
/// 子类在 -configureTabBarContent 中赋值：每个 Tab 的 SF Symbol 名称，与 viewControllers 一一对应
@property (nonatomic, copy) NSArray<NSString *> *tabSymbolNames;

/// 程序化切换选中的 Tab 索引，并切换对应 VC
- (void)setSelectedIndex:(NSInteger)index;

/// 子类重写此方法，在其中设置 self.viewControllers / self.tabTitles / self.tabSymbolNames。基类在 viewDidLoad 中先执行 setupLayout，再调用本方法，最后根据上述数据创建 Tab 按钮并显示第一个 Tab。
- (void)configureTabBarContent;

/// 显示或隐藏底部 TabBar（供子类或外部控制 hidesBottomBarWhenPushed 等场景使用）
- (void)setTabBarHidden:(BOOL)hidden;

@end

NS_ASSUME_NONNULL_END
