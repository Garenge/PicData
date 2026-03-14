//
//  PDTabBarController.m
//  PicData
//
//  自定义底部 Tab 容器基类：布局、大屏/小屏切换、选中态等均由基类实现；
//  子类仅需实现 -configureTabBarContent 并赋值 viewControllers / tabTitles / tabSymbolNames。
//

#import "PDTabBarController.h"
#import <Masonry/Masonry.h>

/// 窗口宽度 >= 此值视为大屏，Tab 为「图左文右」；否则为小屏「图上文下」
static const CGFloat kPDTabBarLargeScreenWidthThreshold = 600.0;
/// 底部 TabBar 高度（略小于默认 UITabBar，看起来更紧凑）
static const CGFloat kPDTabBarHeight = 50.0;
/// 图标和文字尺寸，适当缩小以适配本项目整体风格
static const CGFloat kPDTabBarSymbolPointSize = 15.0;
static const CGFloat kPDTabBarTitleFontSize = 11.0;

@interface PDTabBarItemView : UIControl

@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *titleLabel;

@end

@implementation PDTabBarItemView

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.userInteractionEnabled = NO;

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.userInteractionEnabled = NO;

        _stackView = [[UIStackView alloc] initWithArrangedSubviews:@[_imageView, _titleLabel]];
        _stackView.axis = UILayoutConstraintAxisVertical;
        _stackView.alignment = UIStackViewAlignmentCenter;
        _stackView.spacing = 6.0;
        _stackView.layoutMargins = UIEdgeInsetsMake(6.0, 0.0, 6.0, 0.0);
        _stackView.layoutMarginsRelativeArrangement = YES;
        _stackView.userInteractionEnabled = NO;
        _stackView.translatesAutoresizingMaskIntoConstraints = NO;

        [self addSubview:_stackView];

        [NSLayoutConstraint activateConstraints:@[
            [_stackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_stackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_stackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:4.0],
            [_stackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-4.0],
        ]];
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];

    CGFloat scale = highlighted ? 0.95 : 1.0;
    CGFloat alpha = highlighted ? 0.6 : 1.0;

    [UIView animateWithDuration:0.12
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.stackView.transform = CGAffineTransformMakeScale(scale, scale);
                         self.alpha = alpha;
                     }
                     completion:nil];
}

@end

@interface PDTabBarController ()

@property (nonatomic, assign, readwrite) NSInteger selectedIndex;

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *tabBarView;
@property (nonatomic, copy) NSArray<PDTabBarItemView *> *tabButtons;
@property (nonatomic, assign) BOOL isLargeScreenLayout;

@end

@implementation PDTabBarController

- (UIViewController *)selectedViewController {
    if (self.selectedIndex >= 0 && self.selectedIndex < (NSInteger)self.viewControllers.count) {
        return self.viewControllers[self.selectedIndex];
    }
    return nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    _selectedIndex = NSNotFound;

    [self setupLayout];
    [self configureTabBarContent];
    [self setupTabButtons];
    [self updateTabBarLayoutFromCurrentSize];
    [self switchToIndex:0];
    [self updateTabButtonStates];
}

- (void)setupLayout {
    UIView *container = [[UIView alloc] init];
    [self.view addSubview:container];
    self.containerView = container;

    UIView *tabBar = [[UIView alloc] init];
    tabBar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [self.view addSubview:tabBar];
    self.tabBarView = tabBar;

    [tabBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
        make.height.mas_equalTo(kPDTabBarHeight);
    }];

    [container mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.tabBarView.mas_top);
    }];
}

- (void)configureTabBarContent {
    // 子类重写并设置 self.viewControllers / self.tabTitles / self.tabSymbolNames
}

- (void)setupTabButtons {
    NSArray<NSString *> *titles = self.tabTitles;
    NSArray<NSString *> *symbolNames = self.tabSymbolNames;
    if (!titles.count || titles.count != symbolNames.count || titles.count != self.viewControllers.count) {
        return;
    }

    NSMutableArray<PDTabBarItemView *> *buttons = [NSMutableArray arrayWithCapacity:titles.count];
    PDTabBarItemView *previous = nil;

    for (NSInteger i = 0; i < titles.count; i++) {
        PDTabBarItemView *item = [[PDTabBarItemView alloc] init];
        item.tag = i;
        [item addTarget:self action:@selector(pd_tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:kPDTabBarSymbolPointSize weight:UIImageSymbolWeightRegular];
        UIImage *image = [UIImage systemImageNamed:symbolNames[i] withConfiguration:symbolConfig];
        item.imageView.image = image;
        item.imageView.tintColor = [UIColor labelColor];
        item.titleLabel.text = titles[i];
        item.titleLabel.font = [UIFont systemFontOfSize:kPDTabBarTitleFontSize];

        [self.tabBarView addSubview:item];
        [buttons addObject:item];

        [item mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.equalTo(self.tabBarView);
            if (previous) {
                make.left.equalTo(previous.mas_right);
                make.width.equalTo(previous);
            } else {
                make.left.equalTo(self.tabBarView.mas_left);
            }
            if (i == titles.count - 1) {
                make.right.equalTo(self.tabBarView.mas_right);
            }
        }];

        previous = item;
    }

    self.tabButtons = buttons;
    self.isLargeScreenLayout = NO;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateTabBarLayoutFromCurrentSize];
}

#pragma mark - 大屏/小屏布局

- (BOOL)pd_isLargeScreenWithWidth:(CGFloat)width {
    return width >= kPDTabBarLargeScreenWidthThreshold;
}

- (void)pd_applyImagePlacementForConfiguration:(UIButtonConfiguration *)config largeScreen:(BOOL)largeScreen API_AVAILABLE(ios(15.0)) {
    // 旧式布局已使用 imageEdgeInsets / titleEdgeInsets，这里不再依赖 UIButtonConfiguration
}

- (void)pd_applyImagePlacementToButtons:(BOOL)largeScreen {
    // 保留接口以兼容旧代码，但实际不做任何事
}

- (void)updateTabBarLayoutFromCurrentSize {
    CGFloat width = self.view.bounds.size.width;
    BOOL large = [self pd_isLargeScreenWithWidth:width];
    if (large == self.isLargeScreenLayout) return;
    self.isLargeScreenLayout = large;
    [self pd_applyLayoutToButtons:large];
}

- (void)pd_applyLayoutToButtons:(BOOL)largeScreen {
    UILayoutConstraintAxis axis = largeScreen ? UILayoutConstraintAxisHorizontal : UILayoutConstraintAxisVertical;
    CGFloat spacing = largeScreen ? 8.0 : 6.0;
    NSTextAlignment alignment = largeScreen ? NSTextAlignmentLeft : NSTextAlignmentCenter;

    [self.tabButtons enumerateObjectsUsingBlock:^(PDTabBarItemView * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        item.stackView.axis = axis;
        item.stackView.spacing = spacing;
        item.titleLabel.textAlignment = alignment;
    }];
}

#pragma mark - Tab 切换与选中态

- (void)pd_tabButtonTapped:(UIControl *)sender {
    [self switchToIndex:sender.tag];
}

- (void)setSelectedIndex:(NSInteger)index {
    [self switchToIndex:index];
}

- (void)switchToIndex:(NSInteger)index {
    if (index < 0 || index >= self.viewControllers.count) return;
    if (self.selectedIndex == index) return;

    if (self.selectedIndex != NSNotFound) {
        UIViewController *oldVC = self.viewControllers[self.selectedIndex];
        [oldVC willMoveToParentViewController:nil];
        [oldVC.view removeFromSuperview];
        [oldVC removeFromParentViewController];
    }

    UIViewController *newVC = self.viewControllers[index];
    [self addChildViewController:newVC];
    newVC.view.frame = self.containerView.bounds;
    newVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.containerView addSubview:newVC.view];
    [newVC didMoveToParentViewController:self];

    _selectedIndex = index;
    [self updateTabButtonStates];
}

- (void)updateTabButtonStates {
    UIFont *regularFont = [UIFont systemFontOfSize:kPDTabBarTitleFontSize];
    UIFont *boldFont = [UIFont boldSystemFontOfSize:kPDTabBarTitleFontSize];
    [self.tabButtons enumerateObjectsUsingBlock:^(PDTabBarItemView * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL selected = (idx == self.selectedIndex);
#ifdef ThemeColor
        UIColor *color = selected ? ThemeColor : ThemeDisabledColor;
#else
        UIColor *color = selected ? [UIColor systemBlueColor] : [UIColor secondaryLabelColor];
#endif
        item.imageView.tintColor = color;
        item.titleLabel.textColor = color;
        item.titleLabel.font = selected ? boldFont : regularFont;
    }];
}

- (void)setTabBarHidden:(BOOL)hidden {
    self.tabBarView.hidden = hidden;
}

@end
