//
//  ViewerContentSelCell.h
//  PicData
//
//  Created by Garenge on 2024/11/3.
//  Copyright © 2024 garenge. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ViewerContentSelCell : UICollectionViewCell

@property (nonatomic, weak) SDWebImageManager *manager;

@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) NSString *targetPath;

@property (nonatomic, strong) ViewerFileModel *fileModel;

@property (nonatomic, strong) UIImageView *selImageView;

@property (nonatomic, assign) BOOL isEditing;

@end

NS_ASSUME_NONNULL_END
