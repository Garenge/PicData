//
//  PDDownloadManager.h
//  PicData
//
//  Created by Garenge on 2020/4/19.
//  Copyright © 2020 garenge. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PicSourceModel.h"
#import "PicContentModel.h"
#import "AppDelegate.h"
#import "DataDemoModel.h"

#define NOTICECHECKDOWNLOADPATHKEY @"NOTICECHECKDOWNLOADPATHKEY"
#define NOTICEPICDOWNLOADSUCCESS @"NOTICEPICDOWNLOADSUCCESS"

NS_ASSUME_NONNULL_BEGIN

@interface PDDownloadManager : NSObject

singleton_interface(PDDownloadManager);

@property (nonatomic, strong) NSArray <DataDemoModel *>* dataDemoModels;

- (NSInteger)defaultMinDownloadOperationCount;
- (NSInteger)defaultMaxDownloadOperationCount;
/// 同时下载的图片的数量, 默认6
@property (nonatomic, assign) NSInteger maxDownloadOperationCount;

/// 重置当前下载相对地址
- (BOOL)resetDownloadPath;
/// 获取默认下载相对地址
- (nonnull NSString *)defaultDownloadPath;
/// 获取系统下载相对地址
- (nonnull NSString *)systemDownloadPath;
/// 获取当前系统的完整下载地址
- (nonnull NSString *)systemDownloadFullPath;
/// 获取当前系统的文件夹名
- (nonnull NSString *)systemDownloadFullDirectory;
/// 获取当前系统收藏文件夹路径
- (nonnull NSString *)systemFavoriteFolderPath;
/// 获取当前系统收藏文件夹名称
- (nonnull NSString *)systemFavoriteFolderName;
/// 获取当前系统分享文件夹路径
- (nonnull NSString *)systemShareFolderPath;
/// 获取当前系统分享文件夹名称
- (nonnull NSString *)systemShareFolderName;
/// 数据库文件名
@property (nonatomic, strong) NSString *databaseFileName;
/// 数据库文件路径
@property (nonatomic, strong) NSString *databaseFilePath;
/// 配置数据库
+ (void)prepareDatabase;
/// 删除数据库
+ (BOOL)deleteDatabase;

+ (BOOL)clearAllData:(BOOL)andFiles;

- (BOOL)checksystemDownloadFullPathExistNeedNotice:(BOOL)need;

/// 设置下载地址
- (BOOL)updatesystemDownloadPath:(nonnull NSString *)downloadPath;

/// 根据模型获取下载地址
- (NSString *)getDirPathWithSource:(nullable PicSourceModel *)sourceModel contentModel:(nullable PicContentModel *)contentModel;
/// 创建下载任务
- (void)downWithSource:(PicSourceModel *)sourceModel ContentTaskModel:(PicContentTaskModel *)contentTaskModel urls:(NSArray *)urls referer: (NSString *)referer suggestNames:(nullable NSArray <NSString *> *)suggestNames;

/// 全部取消
- (void)cancelAllDownloads;
/// 取消某个任务(根据任务的href)
- (void)cancelDownloadsByIdentifiers:(NSArray <NSString *>*)identifiers;

@end

NS_ASSUME_NONNULL_END
