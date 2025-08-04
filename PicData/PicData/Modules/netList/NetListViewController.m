//
//  NetListViewController.m
//  PicData
//
//  Created by 鹏鹏 on 2022/2/18.
//  Copyright © 2022 garenge. All rights reserved.
//

#import "NetListViewController.h"
#import "NetListTCell.h"

@interface NetListViewController() <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSArray <PicNetModel *>* dataList;

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) PicNetModel *selectedModel;

@end

@implementation NetListViewController

@synthesize selectedModel = _selectedModel;
- (PicNetModel *)selectedModel {
    if (nil == _selectedModel) {
        _selectedModel = [AppTool sharedAppTool].currentHostModel;
    }
    return _selectedModel;
}

- (void)setSelectedModel:(PicNetModel *)selectedModel {
    _selectedModel = selectedModel;
    [AppTool sharedAppTool].currentHostModel = selectedModel;

    PPIsBlockExecute(self.refreshBlock);
}

- (NSArray<PicNetModel *> *)dataList {
    if (nil == _dataList) {
        _dataList = [NSArray arrayWithArray:[AppTool sharedAppTool].hostModels];
    }
    return _dataList;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)loadMainView {

    self.view.backgroundColor = UIColor.whiteColor;

    UIView *bottomBar = [UIView pp_view];
    [self.view addSubview:bottomBar];
    [bottomBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.mas_equalTo(0);
        make.bottom.equalTo(self.view.mas_bottomMargin);
        make.height.mas_equalTo(56);
    }];

    UIButton *exportButton = [UIButton pp_buttonWithTitle:@"导出数据" titleColor:ThemeColor titleFont:[UIFont systemFontOfSize:14]];
    [exportButton addTarget:self action:@selector(doExportDataBtnAction:) forControlEvents:UIControlEventTouchUpInside];

    [bottomBar addSubview:exportButton];
    [exportButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(16);
        make.height.mas_equalTo(36);
        make.centerY.equalTo(bottomBar);
        make.width.mas_equalTo((self.targetWidth > 0 ? self.targetWidth : 300) - 32);
    }];

    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    tableView.delegate = self;
    tableView.dataSource = self;
    [self.view addSubview:tableView];
    self.tableView = tableView;

    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.topMargin.mas_equalTo(0);
        make.bottom.equalTo(bottomBar.mas_top);
        make.width.mas_equalTo(self.targetWidth > 0 ? self.targetWidth : 300);
    }];
}

#pragma mark - action

- (void)doExportDataBtnAction:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    PPIsBlockExecute(self.didShareConfigFile);
}

#pragma mark - UITableViewDelegate, UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *identifier = @"NetListTCell";
    NetListTCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

    if (nil == cell) {
        cell = [[NetListTCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }

    PicNetModel *netModel = self.dataList[indexPath.row];
    cell.hostModel = netModel;
    cell.isForcus = [netModel.HOST_URL isEqualToString:self.selectedModel.HOST_URL];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    self.selectedModel = self.dataList[indexPath.row];
    [tableView reloadData];
}

@end
