//
//  SettingOperationModel.h
//  PicData
//
//  Created by Garenge on 2025/5/31.
//  Copyright © 2025 garenge. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SettingOperationModel : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, strong) NSString *func;
@property (nonatomic, strong) NSArray <SettingOperationModel *>*subOperationModels;


+ (instancetype)ModelWithName:(NSString *)name value:(NSString *)value func:(NSString *)func;

@end

NS_ASSUME_NONNULL_END
