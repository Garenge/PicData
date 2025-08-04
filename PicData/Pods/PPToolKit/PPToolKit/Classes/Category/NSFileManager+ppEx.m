//
//  NSFileManager+ppEx.m
//  PPToolKit
//
//  Created by Garenge on 2025/7/18.
//

#import "NSFileManager+ppEx.h"

@implementation NSFileManager (HEEx)

- (BOOL)doReplaceFile:(NSString *)localFilePath withNewFileContent:(NSData *)newFileContent {
    NSLog(@"======== 准备替换本地文件, 本地文件: %@, 新下载文件数据大小: %ld字节", localFilePath, newFileContent.length);
    if (newFileContent.length == 0) {
        NSLog(@"======== 下载的数据为空, 替换失败");
        return NO;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:localFilePath]) {
        NSError *rmError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:localFilePath error:&rmError];
        if (rmError) {
            NSLog(@"======== 移除旧文件: %@ 失败: %@", localFilePath, rmError);
            return NO;
        }
    }
    NSError *wrError = nil;
    [newFileContent writeToFile:localFilePath options:NSDataWritingAtomic error:&wrError];
    if (wrError) {
        NSLog(@"======== 替换文件失败: %@", wrError);
        return NO;
    }
    return YES;
}

- (BOOL)doReplaceFile:(NSString *)localFilePath withNewFilePath:(NSString *)newFilePath {
    NSLog(@"======== 准备替换本地文件, 本地文件: %@, 新下载文件: %@", localFilePath, newFilePath);
    if (![[NSFileManager defaultManager] fileExistsAtPath:newFilePath]) {
        NSLog(@"======== 下载的数据不存在, 替换失败");
        return NO;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:localFilePath]) {
        NSError *rmError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:localFilePath error:&rmError];
        if (rmError) {
            NSLog(@"======== 移除旧文件: %@ 失败: %@", localFilePath, rmError);
            return NO;
        }
    }
    NSError *cpError = nil;
    [[NSFileManager defaultManager] copyItemAtPath:newFilePath toPath:localFilePath error:&cpError];
    if (cpError) {
        NSLog(@"======== 替换文件失败: %@", cpError);
        return NO;
    }
    return YES;
}

@end
