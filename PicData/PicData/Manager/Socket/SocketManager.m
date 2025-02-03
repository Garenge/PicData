//
//  SocketManager.m
//  PicData
//
//  Created by Garenge on 2023/5/29.
//  Copyright © 2023 garenge. All rights reserved.
//

#import "SocketManager.h"
#import <PPSocket/PPSocket-Swift.h>

@interface SocketManager() <GCDAsyncSocketDelegate>

@property (nonatomic, strong) PPClientSocketManager *client;

@end

@implementation SocketManager

singleton_implementation(SocketManager)

- (PPClientSocketManager *)client {
    if (nil == _client) {
        _client = [[PPClientSocketManager alloc] init];
    }
    return _client;
}

- (BOOL)isConnected {
    return self.client.socket.isConnected;
}

- (void)connect {
    if (!self.isConnected) {
        NSError *error = nil;
        [self.client.socket connectToHost:@"127.0.0.1" onPort:12138 error:&error];
        if (error) {
            NSLog(@"SocketManager: 连接socket服务器失败, 请先打开DataDemo");
        }
    } else {
        [self sendMessage:@"Hello, dataDemo!"];
    }
}

- (void)sendMessage:(NSString *)message {
    SocketMessageModel *model = [[SocketMessageModel alloc] initWithEvent:@"test"];
    model.message = message;
    [self.client sendDirectionMessageWith:model.toString completeHandler:^(NSString * _Nullable message, NSError * _Nullable error) {
        if (error) {
            NSLog(@"PicData receive data failed: %@", error);
        } else {
            NSLog(@"PicData receive data success: %@", message);
        }
    }];
}

#pragma mark - func
- (void)scan {
    SocketMessageModel *model = [[SocketMessageModel alloc] initWithEvent:@"scan"];
    [self.client sendDirectionMessageWith:model.toString completeHandler:^(NSString * _Nullable message, NSError * _Nullable error) {
        if (error) {
            NSLog(@"PicData receive data failed: %@", error);
        } else {
            NSLog(@"PicData receive data success: %@", message);
        }
    }];
}

@end
