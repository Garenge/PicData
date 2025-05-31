//
//  SettingPathViewController.h
//  PicData
//
//  Created by Garenge on 2021/4/11.
//  Copyright © 2021 garenge. All rights reserved.
//

#import "BaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface SettingPathViewController : BaseViewController

@property (nonatomic, copy) void (^didUpdateData)(void);

@end

NS_ASSUME_NONNULL_END
