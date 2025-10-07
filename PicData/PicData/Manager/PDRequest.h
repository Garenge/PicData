//
//  PDRequest.h
//  PicData
//
//  Created by CleverPeng on 2020/8/2.
//  Copyright © 2020 garenge. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PDRequest : NSObject

singleton_interface(PDRequest)

// 代理配置相关方法
+ (void)setProxyEnabled:(BOOL)enabled;
+ (void)setProxyHost:(NSString *)host port:(NSInteger)port;
+ (void)setProxyCredentials:(NSString *)username password:(NSString *)password;
+ (void)printCurrentProxyConfig; // 调试方法，打印当前代理配置
+ (void)testProxyConnection; // 测试代理连接
+ (void)setupMacCatalystProxy; // 专门为Mac Catalyst设置代理
+ (void)testDifferentProxyConfigs; // 测试不同的代理配置

+ (NSURLSessionDataTask *)getWithURL:(NSURL *)URL completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
+ (NSURLSessionDataTask *)getWithURL:(NSURL *)URL isPhone:(BOOL)isPhone completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
+ (NSURLSessionDataTask *)getWithURL:(NSURL *)URL userAgent:(NSString *)userAgent completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

+ (void)requestToCheckVersion:(BOOL)autoCheck onView:(UIView *)onView completehandler:(void(^ __nullable )(void))completehandler;
@end

NS_ASSUME_NONNULL_END
