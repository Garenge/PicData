//
//  PicBrowserToolViewHandler.h
//  PicData
//
//  Created by Garenge on 2020/11/25.
//  Copyright © 2020 garenge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YBImageBrowser/YBImageBrowser+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface PicBrowserToolViewHandler : NSObject <YBIBToolViewHandler>

- (void)setEyeShow:(BOOL)isShow;

/// 点击隐藏显示操作按钮
@property (nonatomic, copy) void(^didClickedEyeShowBtnBlock)(BOOL isShow);

@end

NS_ASSUME_NONNULL_END
