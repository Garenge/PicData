//
//  SettingViewController.h
//  PicData
//
//  Created by CleverPeng on 2020/7/19.
//  Copyright © 2020 garenge. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SettingOperationModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface SettingViewController : BaseViewController

@property (nonatomic, strong) NSArray <SettingOperationModel *>* operationModels;

@end

NS_ASSUME_NONNULL_END
