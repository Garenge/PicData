//
//  ViewerContentSelCell.m
//  PicData
//
//  Created by Garenge on 2024/11/3.
//  Copyright © 2024 garenge. All rights reserved.
//

#import "ViewerContentSelCell.h"
#import "ViewerFileSModel.h"

@interface ViewerContentSelCell ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *sizeLabel;

@end

@implementation ViewerContentSelCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupSubviews_jkl];
    }
    return self;
}

- (void)setupSubviews_jkl {
    
    UIView *bgView = [[UIView alloc] init];
    bgView.backgroundColor = UIColor.whiteColor;
    [self.contentView addSubview:bgView];
    
    [bgView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(UIEdgeInsetsMake(0, 0, 0, 0));
    }];
    
    bgView.layer.cornerRadius = 8;
    bgView.layer.masksToBounds = YES;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:10];
    titleLabel.textColor = rgba(63, 63, 63, 1);
    titleLabel.numberOfLines = 3;
    [bgView addSubview:titleLabel];
    self.titleLabel = titleLabel;
    
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(2);
        make.right.mas_equalTo(-2);
        make.height.mas_lessThanOrEqualTo(40);
        make.bottom.mas_equalTo(-2);
    }];
    
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.backgroundColor = UIColor.clearColor;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    [bgView addSubview:imageView];
    imageView.layer.masksToBounds = YES;
    self.imageView = imageView;
    
    [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(0);
        make.left.mas_equalTo(0);
        make.right.mas_equalTo(0);
        make.bottom.equalTo(titleLabel.mas_top).with.offset(-2);
    }];
    
    UILabel *countLabel = [[UILabel alloc] init];
    countLabel.textAlignment = NSTextAlignmentCenter;
    countLabel.font = [UIFont systemFontOfSize:10];
    countLabel.textColor = rgba(63, 63, 63, 1);
    [bgView addSubview:countLabel];
    self.countLabel = countLabel;
    
    [countLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(bgView).with.offset(5);
        make.right.equalTo(bgView).with.offset(-5);
        make.height.mas_equalTo(20);
    }];
    
    UILabel *sizeLabel = [[UILabel alloc] init];
    sizeLabel.textAlignment = NSTextAlignmentCenter;
    sizeLabel.font = [UIFont systemFontOfSize:10];
    sizeLabel.textColor = rgba(63, 63, 63, 1);
    [bgView addSubview:sizeLabel];
    self.sizeLabel = sizeLabel;
    
    [sizeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(bgView).with.offset(5);
        make.left.equalTo(bgView).with.offset(5);
        make.height.mas_equalTo(20);
    }];
    
    self.contentView.layer.shadowColor = [UIColor blackColor].CGColor;//shadowColor阴影颜色
    self.contentView.layer.shadowOffset = CGSizeMake(0,0);//shadowOffset阴影偏移,x向右偏移4，y向下偏移4，默认(0, -3),这个跟shadowRadius配合使用
    self.contentView.layer.shadowOpacity = 0.15;//阴影透明度，默认0
    self.contentView.layer.shadowRadius = 5;//阴影半径，默认3
    
    UIImageView *selImageView = [[UIImageView alloc] initWithImage: [UIImage systemImageNamed:@"circle"]];
    [self.contentView addSubview:selImageView];
    selImageView.hidden = YES;
    self.selImageView = selImageView;
    [selImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(24);
        make.right.mas_equalTo(-8);
        make.top.mas_equalTo(8);
    }];
}

- (void)setIsEditing:(BOOL)isEditing {
    _isEditing = isEditing;
    
    if (isEditing) {
        self.selImageView.hidden = NO;
        self.selImageView.image = [UIImage systemImageNamed:@"circle"];
    } else {
        self.selImageView.hidden = YES;
    }
}

- (void)setFileModel:(ViewerFileModel *)fileModel {
    
    _fileModel = fileModel;
    
    if (fileModel.isFolder) {
        self.imageView.image = [UIImage imageNamed:@"file_type_v_folder" inBundle:[PPFileManager getResourceBundle] compatibleWithTraitCollection:nil];
        self.countLabel.hidden = NO;
        self.countLabel.text = fileModel.fileCount > 0 ? [NSString stringWithFormat:@"%ld", fileModel.fileCount] : @"";
        
        self.sizeLabel.text = fileModel.fileSize > 0 ? [NSString fileSizeFormat:fileModel.fileSize] : @"";
        self.sizeLabel.hidden = NO;
    } else {
        if ([PPFileManager isFileTypeDocument:fileModel.fileName.pathExtension]) {
            self.imageView.image = [UIImage imageNamed:@"file_type_v_txt" inBundle:[PPFileManager getResourceBundle] compatibleWithTraitCollection:nil];
        } else {
            SDWebImageContext *context = @{SDWebImageContextCustomManager: self.manager};
            [self.imageView sd_setImageWithURL:[NSURL fileURLWithPath:[self.targetPath stringByAppendingPathComponent:fileModel.fileName]] placeholderImage:[UIImage imageNamed:@"file_type_v_image" inBundle:[PPFileManager getResourceBundle] compatibleWithTraitCollection:nil] options:0 context:context];
        }
        self.countLabel.text = @"";
        self.countLabel.hidden = YES;
        
        self.sizeLabel.text = @"";
        self.sizeLabel.hidden = YES;
    }
    self.titleLabel.text = [fileModel.fileName stringByReplacingOccurrencesOfString:@":" withString:@"/"];
    
    
    if ([fileModel isKindOfClass:[ViewerFileSModel class]]) {
        self.selImageView.image = ((ViewerFileSModel *)fileModel).isSelected ? [UIImage systemImageNamed:@"checkmark.circle.fill"] : [UIImage systemImageNamed:@"circle"];
    }
}


@end
