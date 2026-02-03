//
//  PDRequest.m
//  PicData
//
//  Created by CleverPeng on 2020/8/2.
//  Copyright © 2020 garenge. All rights reserved.
//

#import "PDRequest.h"

@interface PDRequest() <NSURLSessionDelegate>

@property (nonatomic, assign) BOOL proxyEnabled;
@property (nonatomic, strong) NSString *proxyHost;
@property (nonatomic, assign) NSInteger proxyPort;
@property (nonatomic, strong) NSString *proxyUsername;
@property (nonatomic, strong) NSString *proxyPassword;

@end

@implementation PDRequest

singleton_implementation(PDRequest)

- (instancetype)init {
    self = [super init];
    if (self) {
        // 默认启用代理配置，使用你的环境变量设置
        _proxyEnabled = NO;
//        _proxyEnabled = YES;
        _proxyHost = @"127.0.0.1";
        _proxyPort = 7890;
    }
    return self;
}

#pragma mark - 代理配置方法

+ (void)setProxyEnabled:(BOOL)enabled {
    [PDRequest sharedPDRequest].proxyEnabled = enabled;
}

+ (void)setProxyHost:(NSString *)host port:(NSInteger)port {
    PDRequest *instance = [PDRequest sharedPDRequest];
    instance.proxyHost = host;
    instance.proxyPort = port;
}

+ (void)setProxyCredentials:(NSString *)username password:(NSString *)password {
    PDRequest *instance = [PDRequest sharedPDRequest];
    instance.proxyUsername = username;
    instance.proxyPassword = password;
}

+ (void)printCurrentProxyConfig {
    PDRequest *instance = [PDRequest sharedPDRequest];
    NSLog(@"=== 当前代理配置 ===");
    NSLog(@"代理启用: %@", instance.proxyEnabled ? @"是" : @"否");
    NSLog(@"代理主机: %@", instance.proxyHost ?: @"未设置");
    NSLog(@"代理端口: %ld", (long)instance.proxyPort);
    NSLog(@"代理用户名: %@", instance.proxyUsername ?: @"未设置");
    NSLog(@"代理密码: %@", instance.proxyPassword ? @"已设置" : @"未设置");
    NSLog(@"==================");
}

+ (void)testProxyConnection {
    NSLog(@"🧪 开始测试代理连接...");
    
    // 测试IP地址查询
    [PDRequest getWithURL:[NSURL URLWithString:@"https://httpbin.org/ip"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ 代理测试失败: %@", error.localizedDescription);
        } else if (data) {
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"✅ 代理测试成功，响应: %@", responseString);
        }
    }];
    
    // 测试另一个服务
    [PDRequest getWithURL:[NSURL URLWithString:@"https://api.ipify.org?format=json"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ 第二个代理测试失败: %@", error.localizedDescription);
        } else if (data) {
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"✅ 第二个代理测试成功，响应: %@", responseString);
        }
    }];
}

+ (void)setupMacCatalystProxy {
    NSLog(@"🍎 设置Mac Catalyst代理配置...");
    
    // 确保代理配置正确
    [PDRequest setProxyEnabled:YES];
    [PDRequest setProxyHost:@"127.0.0.1" port:7890];
    
    // 打印当前配置
    [PDRequest printCurrentProxyConfig];
    
    // 测试连接
    [PDRequest testProxyConnection];
}

+ (void)testDifferentProxyConfigs {
    NSLog(@"🧪 测试不同的代理配置...");
    
    // 测试1: 禁用代理，直接连接
    NSLog(@"📋 测试1: 禁用代理");
    [PDRequest setProxyEnabled:NO];
    [PDRequest getWithURL:[NSURL URLWithString:@"https://httpbin.org/ip"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ 直接连接失败: %@", error.localizedDescription);
        } else {
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"✅ 直接连接成功: %@", responseString);
        }
        
        // 测试2: 启用代理
        NSLog(@"📋 测试2: 启用代理");
        [PDRequest setProxyEnabled:YES];
        [PDRequest setProxyHost:@"127.0.0.1" port:7890];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [PDRequest getWithURL:[NSURL URLWithString:@"https://httpbin.org/ip"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"❌ 代理连接失败: %@", error.localizedDescription);
                } else {
                    NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    NSLog(@"✅ 代理连接成功: %@", responseString);
                }
            }];
        });
    }];
}

#pragma mark - 创建带代理配置的Session

- (NSURLSession *)createSessionWithConfiguration {
    return [NSURLSession sharedSession];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 15; // 增加超时时间
    
    // 如果启用了代理，配置代理设置
    if (self.proxyEnabled && self.proxyHost && self.proxyPort > 0) {
        NSMutableDictionary *proxyDict = [NSMutableDictionary dictionary];
        
        // 使用最兼容的代理配置方式
        // HTTP代理配置
        proxyDict[@"HTTPEnable"] = @YES;
        proxyDict[@"HTTPProxy"] = self.proxyHost;
        proxyDict[@"HTTPPort"] = @(self.proxyPort);
        
        // HTTPS代理配置 - 使用CONNECT方法
        proxyDict[@"HTTPSEnable"] = @YES;
        proxyDict[@"HTTPSProxy"] = self.proxyHost;
        proxyDict[@"HTTPSPort"] = @(self.proxyPort);
        
        // 添加额外的配置选项
        proxyDict[@"HTTPUser"] = @"";  // 空用户名
        proxyDict[@"HTTPPassword"] = @"";  // 空密码
        
        // 如果有认证信息，添加认证
        if (self.proxyUsername && self.proxyPassword) {
            proxyDict[@"HTTPUser"] = self.proxyUsername;
            proxyDict[@"HTTPPassword"] = self.proxyPassword;
        }
        
        config.connectionProxyDictionary = proxyDict;
        
        // 调试日志
        NSLog(@"🔧 代理配置已应用: %@:%ld", self.proxyHost, (long)self.proxyPort);
        NSLog(@"🔧 代理字典: %@", proxyDict);
    } else {
        NSLog(@"⚠️ 代理未启用或配置不完整");
    }
    
    return [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
}

+ (NSURLSessionDataTask *)getWithURL:(NSURL *)URL completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    return [PDRequest getWithURL:URL isPhone:YES completionHandler:completionHandler];
}

+ (NSURLSessionDataTask *)getWithURL:(NSURL *)URL isPhone:(BOOL)isPhone completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    if (isPhone) {
        return [PDRequest getWithURL:URL userAgent:@"Mozilla/5.0 (iPhone; CPU iPhone OS 12_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.2 Mobile/15E148 Safari/604.1" completionHandler:completionHandler];
    } else {
        return [PDRequest getWithURL:URL userAgent:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36 Edg/115.0.1901.203" completionHandler:completionHandler];
    }
}

+ (NSURLSessionDataTask *)getWithURL:(NSURL *)URL userAgent:(NSString *)userAgent completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:userAgent forHTTPHeaderField:@"User-agent"];

    // 使用新的代理配置方法创建session
    NSURLSession *session = [[PDRequest sharedPDRequest] createSessionWithConfiguration];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:completionHandler];
    [dataTask resume];
    return dataTask;
}

+ (void)requestToCheckVersion:(BOOL)autoCheck onView:(UIView *)onView completehandler:(void (^)(void))completehandler {

#if DEBUG

    if (autoCheck) {
        PPIsBlockExecute(completehandler);
        return;
    }
#endif

    [PDRequest getWithURL:[NSURL URLWithString:@"https://garenge.top/app/PicData"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

        if (error) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [PDRequest parasResponse:data completeHandler:^(NSString * _Nullable responseString, NSDictionary * _Nullable responseDataDic, BOOL isSuccess, NSString * _Nullable message) {
                if (!isSuccess) { return; }
                NSArray *array = responseDataDic[@"data"];
                AppInfoModel *appInfoModel = [AppInfoModel mj_objectArrayWithKeyValuesArray:array].firstObject;
                if (nil == appInfoModel) { return; }
                NSLog(@"获取到PicData最新版本为%@, build: %@", appInfoModel.version, appInfoModel.build);

                if (appInfoModel.urlService.length == 0) { return; }

                BOOL sameVersion = [appInfoModel.version isEqualToString:KAppVersion] && [appInfoModel.build isEqualToString:KAppVersionBuild];
                if (sameVersion && autoCheck) { return; }

                NSString *messageAlert = sameVersion ? [NSString stringWithFormat:@"是否直接安装该版本: V%@(build%@)", appInfoModel.version, appInfoModel.build] : [NSString stringWithFormat:@"监测到服务器版本V%@(build%@), 当前app版本V%@(build%@), 是否安装新版本?", appInfoModel.version, appInfoModel.build, KAppVersion, KAppVersionBuild];
                NSString *titleAlert = @"版本提醒";
                NSString *downloadTitle = @"安装";

                UIViewController *presentingViewController = UIApplication.sharedApplication.windows.firstObject.rootViewController;
                [presentingViewController showAlertWithTitle:titleAlert message:messageAlert confirmTitle:downloadTitle confirmHandler:^(UIAlertAction * _Nonnull action) {
                    BOOL isDebugged = AmIBeingDebugged();
                    if (isDebugged) {

                        [presentingViewController showAlertWithTitle:nil message:@"调试模式下不支持直接安装app" confirmTitle:@"好的" confirmHandler:nil];
                    } else {
                        [UIApplication.sharedApplication openURL:[NSURL URLWithString:appInfoModel.urlService] options:@{} completionHandler:nil];
                    }

                    PPIsBlockExecute(completehandler);
                } cancelTitle:@"取消" cancelHandler:^(UIAlertAction * _Nonnull action) {
                    PPIsBlockExecute(completehandler);
                }];

            }];
        });
    }];
}

+ (void)postWith:( NSString * _Nonnull )urlString paramsString:( NSString * _Nullable )paramsString completeHandler:(void(^)(NSString * __nullable responseString, NSDictionary * __nullable responseDataDic, BOOL isSuccess, NSString * _Nullable message))completeHandler; {

    NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [mutableRequest setHTTPMethod:@"POST"];
    [mutableRequest setValue:@"application/x-www-form-urlencoded;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [mutableRequest setHTTPBody:[paramsString dataUsingEncoding:NSUTF8StringEncoding]];
    
    // 使用新的代理配置方法创建session
    NSURLSession *session = [[PDRequest sharedPDRequest] createSessionWithConfiguration];

    PDBlockSelf
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:mutableRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

        [weakSelf parasResponse:data completeHandler:^(NSString * _Nullable responseString, NSDictionary * _Nullable responseDataDic, BOOL isSuccess, NSString * _Nullable message) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(error) {
                    completeHandler(responseString, nil, NO, @"网络请求失败");
                    return;
                }
                completeHandler(responseString, responseDataDic, isSuccess, message);
            });
        }];
    }];
    [dataTask resume];
}

+ (void)parasResponse:(NSData *)data completeHandler:(void(^)(NSString * __nullable responseString, NSDictionary * __nullable responseDataDic, BOOL isSuccess, NSString * _Nullable message))completeHandler {
    if (nil == data || data.length == 0) {
        completeHandler(@"", nil, NO, @"数据解析失败");
        return;
    }

    NSString *returnDataStr = [NSString stringByReplaceUnicode:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];

        // 解析
    NSError *readError = nil;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&readError];

    if (readError) {
        completeHandler(returnDataStr, nil, NO, @"数据解析失败");
        return;
    }

    if ([dictionary[@"code"] intValue] == 200) {
        completeHandler(returnDataStr, dictionary, YES, @"");
        return;
    } else {
        completeHandler(returnDataStr, nil, NO, @"请求失败");
        return;
    }
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
    NSLog(@"didReceiveChallenge ");
    
    // 处理代理认证
    if (challenge.protectionSpace.isProxy) {
        NSLog(@"proxy authentication challenge");
        if (self.proxyUsername && self.proxyPassword) {
            NSURLCredential *credential = [NSURLCredential credentialWithUser:self.proxyUsername 
                                                                   password:self.proxyPassword 
                                                                persistence:NSURLCredentialPersistenceForSession];
            completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
            return;
        } else {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
            return;
        }
    }
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSLog(@"server ---------");
        //        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
        NSString *host = challenge.protectionSpace.host;
        NSLog(@"%@", host);

        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];


        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    }
    else if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodClientCertificate])
        {
            //客户端证书认证
            //TODO:设置客户端证书认证
            // load cert
            NSLog(@"client");
            NSString *path = [[NSBundle mainBundle]pathForResource:@"client"ofType:@"p12"];
            NSData *p12data = [NSData dataWithContentsOfFile:path];
            CFDataRef inP12data = (__bridge CFDataRef)p12data;
            SecIdentityRef myIdentity;
            OSStatus status = [self extractIdentity:inP12data toIdentity:&myIdentity];
            if (status != 0) {
                return;
            }
            SecCertificateRef myCertificate;
            SecIdentityCopyCertificate(myIdentity, &myCertificate);
            const void *certs[] = { myCertificate };
            CFArrayRef certsArray =CFArrayCreate(NULL, certs,1,NULL);
            NSURLCredential *credential = [NSURLCredential credentialWithIdentity:myIdentity certificates:(__bridge NSArray*)certsArray persistence:NSURLCredentialPersistencePermanent];
            //        [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
            //         网上很多错误代码如上，正确的为：
            completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        }
}

- (OSStatus)extractIdentity:(CFDataRef)inP12Data toIdentity:(SecIdentityRef*)identity {
    OSStatus securityError = errSecSuccess;
    CFStringRef password = CFSTR("123456");
    const void *keys[] = { kSecImportExportPassphrase };
    const void *values[] = { password };
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    securityError = SecPKCS12Import(inP12Data, options, &items);
    if (securityError == 0)
        {
            CFDictionaryRef ident = CFArrayGetValueAtIndex(items,0);
            const void *tempIdentity = NULL;
            tempIdentity = CFDictionaryGetValue(ident, kSecImportItemIdentity);
            *identity = (SecIdentityRef)tempIdentity;
        }
    else
        {
            NSLog(@"clinet.p12 error!");
        }

    if (options) {
        CFRelease(options);
    }
    return securityError;
}

@end
