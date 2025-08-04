//
//  NSFileManager+ppEx.h
//  PPToolKit
//
//  Created by Garenge on 2025/7/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSFileManager (HEEx)

/// 将新data写入本地文件
- (BOOL)doReplaceFile:(NSString *)localFilePath withNewFileContent:(NSData *)newFileContent;
/// 将新文件写入本地文件
- (BOOL)doReplaceFile:(NSString *)localFilePath withNewFilePath:(NSString *)newFilePath;

@end

NS_ASSUME_NONNULL_END
