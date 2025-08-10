//
//  PDTestViewController.m
//  PicData
//
//  Created by Garenge on 2025/6/28.
//  Copyright © 2025 garenge. All rights reserved.
//

#import "PDTestViewController.h"
#import "PDTestView.h"

@interface PDTestViewController ()

@end

@implementation PDTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    PDTestView *testView = [[PDTestView alloc] init];
    testView.backgroundColor = UIColor.redColor;
    [self.view addSubview:testView];
    [testView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(300);
        make.right.mas_equalTo(-8);
        make.top.equalTo(self.view.mas_topMargin).offset(8);
        make.bottom.equalTo(self.view.mas_bottom).offset(-8);
    }];
}

@end
