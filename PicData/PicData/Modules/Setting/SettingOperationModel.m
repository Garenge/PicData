//
//  SettingOperationModel.m
//  PicData
//
//  Created by Garenge on 2025/5/31.
//  Copyright © 2025 garenge. All rights reserved.
//

#import "SettingOperationModel.h"

@implementation SettingOperationModel

+ (instancetype)ModelWithName:(NSString *)name value:(NSString *)value func:(NSString *)func {
    SettingOperationModel *operationModel = [[SettingOperationModel alloc] init];
    operationModel.name = name;
    operationModel.value = value;
    operationModel.func = func;
    return operationModel;
}

@end
