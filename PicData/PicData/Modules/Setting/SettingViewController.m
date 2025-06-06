//
//  SettingViewController.m
//  PicData
//
//  Created by CleverPeng on 2020/7/19.
//  Copyright © 2020 garenge. All rights reserved.
//

#import "SettingViewController.h"
#import "SettingPathViewController.h"
#import "SharedListViewController.h"
#import <FirebaseStorage/FirebaseStorage-Swift.h>

@interface SettingViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSString *DataDemoDBDwonloadedPath;

@property (nonatomic, strong) MBProgressHUD *loading;

@end

@implementation SettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(socketDidConnected:) name:NotificationNameSocketDidConnected object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(socketDidDisConnected:) name:NotificationNameSocketDidDisConnected object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (NSString *)getMonitorStatusString {
    return AppTool.sharedAppTool.isPerformanceMonitor ? @"开" : @"关";
}

- (void)reloadData {
    if (self.operationModels.count == 0) {
        self.operationModels = [[self getDefaultOperations] copy];
    }
    [self.tableView reloadData];
}

- (NSArray<SettingOperationModel *> *)operationModels {
    if (nil == _operationModels) {
        _operationModels = @[];
    }
    return _operationModels;
}

- (NSArray<SettingOperationModel *> *)getDefaultOperations {
    
    BOOL isMACCATALYST = NO;
#if TARGET_OS_MACCATALYST
    isMACCATALYST = YES;
#endif
    
    NSLog(@"%@", [[PDDownloadManager sharedPDDownloadManager] systemDownloadFullPath]);
    [[PDDownloadManager sharedPDDownloadManager] checksystemDownloadFullPathExistNeedNotice:NO];
    SettingOperationModel *monitorModel = [SettingOperationModel ModelWithName:@"切换监控开关" value:[self getMonitorStatusString] func:@"checkMonitor:"];

    NSMutableArray *operationModels = [NSMutableArray array];

     [operationModels addObject:[SettingOperationModel ModelWithName:@"查看本地分享" value:@"" func:@"showLocalSharedList:"]];


    // 如果是mac端  // #if !TARGET_OS_MACCATALYST // 如果不是mac端
    // 不用检查
#if !TARGET_OS_MACCATALYST
    // version
    [operationModels addObject:[SettingOperationModel ModelWithName:@"检查更新" value:KAppVersion func:@"checkNewVersion:"]];
    if ([[TKGestureLockManager sharedInstance] checkGettureLockNeeded]) {
        [operationModels addObject:[SettingOperationModel ModelWithName:@"关闭手势锁屏" value:@"" func:@"hideGesture:"]];
    } else {
        [operationModels addObject:[SettingOperationModel ModelWithName:@"显示手势锁屏" value:@"" func:@"showGesture:"]];
    }
#endif

    [operationModels addObject:[SettingOperationModel ModelWithName:@"重置缓存" value:@"" func:@"resetCache:"]];
    [operationModels addObject:monitorModel];

    SettingOperationModel *downloadModel = [SettingOperationModel ModelWithName:@"下载设置" value:@"" func:@""];
    NSMutableArray *downloadSubModels = [NSMutableArray array];
    
    if (isMACCATALYST) {
        // TODO: 设置路径
        /// 目前该功能有点鸡肋, 已屏蔽
        /// 设想应该是Mac端可以自由设置下载路径, 但是暂时设置的是相对documents, 不是我的本意
        /// iOS相对documents设置, Mac端, 直接设置绝对路径, 才合理
        [downloadSubModels addObject:[SettingOperationModel ModelWithName:@"下载路径" value:[[PDDownloadManager sharedPDDownloadManager] systemDownloadPath] func:@"setDownloadPath:"]];
    }
    [downloadSubModels addObject:[SettingOperationModel ModelWithName:@"切换最大同时下载数量" value:[NSString stringWithFormat:@"当前限制最多%ld个任务", [PDDownloadManager sharedPDDownloadManager].maxDownloadOperationCount] func:@"changeMaxDownloadOperationCount:"]];
    [downloadSubModels addObject:[SettingOperationModel ModelWithName:@"一键停止下载" value:@"" func:@"onekeyStopDownload:"]];
    [downloadSubModels addObject:[SettingOperationModel ModelWithName:@"重新下载已完成任务" value:@"" func:@"restartAllDownloads:"]];
    downloadModel.subOperationModels = downloadSubModels;
    [operationModels addObject:downloadModel];
    
    SettingOperationModel *socketModel = [SettingOperationModel ModelWithName:@"Socket" value:@"" func:@""];
    socketModel.subOperationModels = @[
        [SettingOperationModel ModelWithName:@"Socket-连接" value:[NSString stringWithFormat:@"127.0.0.1:12138%@", [SocketManager sharedSocketManager].isConnected ? @"(已连接)" : @"(未连接)"] func:@"socket_connect:"],
        [SettingOperationModel ModelWithName:@"Socket-文件扫描" value:@"" func:@"socket_scan:"]
    ];
    [operationModels addObject:socketModel];
    
    SettingOperationModel *dataModel = [SettingOperationModel ModelWithName:@"数据库" value:@"" func:@""];
    dataModel.subOperationModels = @[
        [SettingOperationModel ModelWithName:@"导出数据库" value:@"" func:@"shareDatabase:"],
    [SettingOperationModel ModelWithName:@"下载DataDemo.db" value:self.DataDemoDBDwonloadedPath.length > 0 ? @"已下载" : @"未下载" func:@"downloadDataDemoDB:"],
    ];
    [operationModels addObject:dataModel];

    return operationModels;
}

- (void)loadNavigationItem {
    self.navigationItem.title = @"设置";
}

- (void)loadMainView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.delegate = self;
    tableView.dataSource = self;
    [self.view addSubview:tableView];
    self.tableView = tableView;

    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.right.mas_equalTo(0);
        make.bottom.equalTo(self.view.mas_bottomMargin).with.offset(0);
    }];

    tableView.tableFooterView = [UIView new];
}

#pragma mark - firebase

- (void)ht_downloadFile:(NSString *)filePath completeHandler:(nonnull void (^)(BOOL isSuccess, NSString * _Nullable fileDownloadPath, NSString * _Nullable showName))completeHandler {
    if (nil == filePath) {
        PPIsBlockExecute(completeHandler, NO, nil, nil);
        return;
    }
    FIRStorage *var_storage = [FIRStorage storage];
    FIRStorageReference *var_storageRef = [var_storage reference];

    // Create a reference to "mountains.jpg"
    FIRStorageReference *var_datasRef = [var_storageRef child:filePath];
    
    NSString *var_downloadFolder = NSTemporaryDirectory();
    NSString *var_fildDownloadPath = [var_downloadFolder stringByAppendingPathComponent:[NSString ht_getRandomFileNameWithPathExtension:filePath.lastPathComponent.pathExtension]];
    
    NSString *var_showName = filePath.lastPathComponent;
    NSLog(@"======== downloadFolder: %@", var_downloadFolder);
    NSLog(@"======== downloadFilePath: %@", var_fildDownloadPath);
    
    // Download to the local filesystem
    FIRStorageDownloadTask *var_downloadTask = [var_datasRef writeToFile:[NSURL fileURLWithPath:var_fildDownloadPath] completion:^(NSURL *URL, NSError *error){
        
        BOOL var_isExist = [[NSFileManager defaultManager] fileExistsAtPath:var_fildDownloadPath];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"======== download file: %@ - error: %@", filePath, error);
                PPIsBlockExecute(completeHandler, NO, var_fildDownloadPath, var_showName);
            } else {
                PPIsBlockExecute(completeHandler, YES, var_fildDownloadPath, var_showName);
            }
        });
      
    }];
}

#pragma mark - tableView delegate, datasource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.operationModels.count;
}

static NSString *identifier = @"identifier";

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    SettingOperationModel *operationModel = self.operationModels[indexPath.row];
    cell.textLabel.text = operationModel.name;
    cell.detailTextLabel.text = operationModel.value;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [self performSelfFuncWithOperationModel:self.operationModels[indexPath.row] withCell:cell];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 54;
}

#pragma mark - func

- (void)performSelfFuncWithOperationModel:(SettingOperationModel *)operationModel withCell:(UITableViewCell *)cell {
    
    if (operationModel.subOperationModels.count > 0) {
        SettingViewController *vc = [[SettingViewController alloc] init];
        vc.operationModels = operationModel.subOperationModels;
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    
    [self performSelfFuncWithString:operationModel.func withObject:operationModel];
}

- (void)checkNewVersion:(UIView *)sender {

    [self showAlertWithTitle:@"检查更新" message:@"检查更新目前只适用于内测服务器, 未添加UDID的请不要尝试更新!!" confirmTitle:@"继续" confirmHandler:^(UIAlertAction * _Nonnull action) {
        PDBlockSelf
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [PDRequest requestToCheckVersion:NO onView:self.view completehandler:^{
            [MBProgressHUD hideHUDForView:weakSelf.view animated:YES];
        }];
    } cancelTitle:@"不更了" cancelHandler:nil];
}

- (void)setDownloadPath:(SettingOperationModel *)operationModel {
    [UIPasteboard generalPasteboard].string = [[PDDownloadManager sharedPDDownloadManager] systemDownloadFullPath];
    [MBProgressHUD showInfoOnView:self.view WithStatus:@"已经复制到粘贴板"];
    SettingPathViewController *vc = [[SettingPathViewController alloc] init];
    vc.didUpdateData = ^{
        operationModel.value = [[PDDownloadManager sharedPDDownloadManager] systemDownloadPath];
        [self reloadData];
    };
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)shareDatabase:(UIView *)sender {
    NSString *dbFilePath = [PDDownloadManager sharedPDDownloadManager].databaseFilePath;
    [AppTool shareFileWithURLs:@[[NSURL fileURLWithPath:dbFilePath]] sourceView:sender completionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        NSLog(@"调用分享的应用id :%@", activityType);
        if (completed) {
            NSLog(@"分享成功!");
        } else {
            NSLog(@"分享失败!");
        }
    }];
}

- (void)showLocalSharedList:(UIView *)sender {
    SharedListViewController *vc = [[SharedListViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES needHiddenTabBar:YES];
}

- (void)onekeyStopDownload:(UIView *)sender {
    [self showAlertWithTitle:@"提示" message:@"是否确定停止所有下载任务?" actions:@[
        [UIAlertAction actionWithTitle:@"仅停止下载" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [ContentParserManager cancelAll];
    }],
        [UIAlertAction actionWithTitle:@"停止并删除未完成任务" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [ContentParserManager cancelAll];
        // TODO: 删除未完成任务
        NSMutableArray *array = [NSMutableArray arrayWithArray:[PicContentTaskModel queryTasksForStatus:0]];
        [array addObjectsFromArray:[PicContentTaskModel queryTasksForStatus:1]];
        [array addObjectsFromArray:[PicContentTaskModel queryTasksForStatus:2]];
        for (PicContentTaskModel *taskModel in array) {
            
            PicSourceModel *sourceModel = [PicSourceModel queryTableWithUrl:taskModel.sourceHref].firstObject;
            if (nil == sourceModel) {
                continue;
            }
            // 更新contentModel就好了
            [PicContentTaskModel deleteFromTableWithHref:taskModel.href];
            NSString *path = [[PDDownloadManager sharedPDDownloadManager] getDirPathWithSource:sourceModel contentModel:taskModel];
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];//可以删除该路径下所有文件包括该文件夹本身
            [NSNotificationCenter.defaultCenter postNotificationName:NotificationNameCancelDownTasks object:nil userInfo:@{@"identifiers": @[taskModel.href ?: @""]}];
        }
    }],
    ]];
}

- (void)restartAllDownloads:(UIView *)sender {
    [self showAlertWithTitle:@"提示" message:@"是否确定重新下载所有任务?" confirmTitle:@"确定" confirmHandler:^(UIAlertAction * _Nonnull action) {
        
        [PicContentTaskModel resetToZeroAllTasks];
        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationNameRefreshDownloadTaskStatus object:nil];
        
    } cancelTitle:@"取消" cancelHandler:nil];
}

- (void)resetCache:(UIView *)sender {

    [AppTool clearSDWebImageCache];

    MJWeakSelf
    void(^clearBlock)(BOOL clear) = ^(BOOL clear){
        if ([PDDownloadManager clearAllData:clear]) {
            [MBProgressHUD showInfoOnView:weakSelf.view WithStatus:@"清理完成"];
            [[NSNotificationCenter defaultCenter] postNotificationName:NotificationNameClearedAllFiles object:nil];
            [weakSelf tipsToReOpenApp];
        } else {
            [MBProgressHUD showInfoOnView:weakSelf.view WithStatus:@"清理失败"];
        }
    };

    UIAlertAction *clearWithFile = [UIAlertAction actionWithTitle:@"确认清除(包括文件)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        clearBlock(YES);
    }];
    UIAlertAction *clearWithoutFile = [UIAlertAction actionWithTitle:@"确认清除(不包括文件)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        clearBlock(NO);
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDestructive handler:nil];
    [self showAlertWithTitle:@"提醒" message:@"是否确认清除全部缓存" actions:@[clearWithFile, clearWithoutFile, cancelAction]];
}

- (void)showGesture:(UIView *)sender {
    [self showAlertWithTitle:@"是否开启手势保护" message:@"开启后, app将显示手势保护界面, 需要输入指定的手势才可以进入app, 当前内置密码是9527" confirmTitle:@"打开" confirmHandler:^(UIAlertAction * _Nonnull action) {
        [[TKGestureLockManager sharedInstance] updateGestureLock:YES];
        [[TKGestureLockManager sharedInstance] saveGesturesPassword:@"8416"];
        [[TKGestureLockManager sharedInstance] showGestureLockWindow];
        [self reloadData];
    } cancelTitle:@"不打开" cancelHandler:nil];
}

- (void)hideGesture:(UIView *)sender {
    [self showAlertWithTitle:@"是否需要关闭手势" message:@"关闭后, APP将缺少隐私保护, 是否继续?" confirmTitle:@"关掉" confirmHandler:^(UIAlertAction * _Nonnull action) {
        [[TKGestureLockManager sharedInstance] updateGestureLock:NO];
        [self reloadData];
    } cancelTitle:@"不关了" cancelHandler:nil];
}

- (void)socket_connect:(UIView *)sender {
    [[SocketManager sharedSocketManager] connect];
}

- (void)socket_scan:(UIView *)sender {
    [[SocketManager sharedSocketManager] scan];
}

- (void)checkMonitor:(SettingOperationModel *)operationModel {
    [AppTool inversePerformanceMonitorStatus];

    operationModel.value = [self getMonitorStatusString];

    NSInteger index = [self.operationModels pp_firstIndex:^BOOL(SettingOperationModel * _Nonnull element) {
        return [element isEqual:operationModel];
    }];
    
    if (index >= 0) {
        [self.tableView reloadRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)tipsToReOpenApp {
    [self showAlertWithTitle:@"提醒" message:@"清理完成, 请重启app" confirmTitle:@"退出app" confirmHandler:^(UIAlertAction * _Nonnull action) {
        abort();
    } cancelTitle:@"以后再说" cancelHandler:nil];
}

- (void)changeMaxDownloadOperationCount:(SettingOperationModel *)operationModel {

    NSString *message = [NSString stringWithFormat:@"设置同时下载的最大图片数量, 该值介于%ld和%ld之间", [PDDownloadManager.sharedPDDownloadManager defaultMinDownloadOperationCount], [PDDownloadManager.sharedPDDownloadManager defaultMaxDownloadOperationCount]];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置最大任务数" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = [NSString stringWithFormat:@"请输入%ld~%ld之间的整数", [PDDownloadManager.sharedPDDownloadManager defaultMinDownloadOperationCount], [PDDownloadManager.sharedPDDownloadManager defaultMaxDownloadOperationCount]];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {

    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"更新" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *field = alert.textFields.firstObject;
        if ([field.text integerValue] > 0) {
            PDDownloadManager.sharedPDDownloadManager.maxDownloadOperationCount = [field.text integerValue];
            operationModel.value = [NSString stringWithFormat:@"当前限制最多%ld个任务", [PDDownloadManager sharedPDDownloadManager].maxDownloadOperationCount];
            [self reloadData];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)downloadDataDemoDB:(SettingOperationModel *)operationModel {
    
    NSMutableArray *actions = [NSMutableArray array];
    NSString *message = @"是否下载DataDemo.db?";
    
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"下载" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        __weak typeof(self) weakSelf = self;
        [self ht_downloadFile:@"DataDemo.db" completeHandler:^(BOOL isSuccess, NSString * _Nullable fileDownloadPath, NSString * _Nullable showName) {
            
            NSLog(@"DataDemo.db download isSuccess: %d, fileDownloadPath: %@", isSuccess, fileDownloadPath);
            
            weakSelf.DataDemoDBDwonloadedPath = fileDownloadPath;
            operationModel.value = weakSelf.DataDemoDBDwonloadedPath.length > 0 ? @"已下载" : @"未下载";
            [weakSelf reloadData];
            [weakSelf handleDownloadDataDemoDB:weakSelf.DataDemoDBDwonloadedPath];
        }];
    }];
    [actions addObject:confirmAction];
    
    if (self.DataDemoDBDwonloadedPath.length > 0) {
        
        message = @"DataDemo.db已下载, 是否重新下载?";
        UIAlertAction *paraseAction = [UIAlertAction actionWithTitle:@"解析DataDemo.db" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self handleDownloadDataDemoDB:self.DataDemoDBDwonloadedPath];
        }];
        [actions addObject:paraseAction];
    }
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [actions addObject:cancelAction];
    
    [self showAlertWithTitle:@"" message:message actions:actions];
}

- (void)handleDownloadDataDemoDB:(NSString *)fileDownloadPath {
    
    if (nil == fileDownloadPath || ![NSFileManager.defaultManager fileExistsAtPath:fileDownloadPath]) {
        
        [MBProgressHUD showInfoOnView:self.view WithStatus:@"获取DataDemo.db失败"];
        return;
    }
    
    [self showAlertWithTitle:@"DataDemo.db已下载" message:@"是否解析DataDemo.db并删除重复文件?" confirmTitle:@"开始解析" confirmHandler:^(UIAlertAction * _Nonnull action) {
        
        [self deleteDownloadedDataDemoDB:fileDownloadPath];
        
    } cancelTitle:@"取消" cancelHandler:^(UIAlertAction * _Nonnull action) {
        
    }];
    
}

- (void)deleteDownloadedDataDemoDB:(NSString *)dataDemoDbPath {
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSArray *finishedTask = [PicContentTaskModel queryTasksForStatus:3];
        
        NSInteger finishedCount = finishedTask.count;
        
        CGFloat progress = 0;
        NSInteger existCount = 0;
        for (NSInteger index = 0; index < finishedCount; index ++) {
            
            PicContentTaskModel *taskModel = finishedTask[index];
            
            NSLog(@"======== 即将处理: %@", taskModel.systemTitle);
            
            DataDemoModel *dataModel = [DataDemoModel queryModelsWithDBUrl:dataDemoDbPath andTitle:taskModel.systemTitle];
            if (dataModel) {
                PicSourceModel *sourceModel = [PicSourceModel queryTableWithUrl:taskModel.sourceHref].firstObject;
                
                NSString *targetFilePath = [[PDDownloadManager sharedPDDownloadManager] getDirPathWithSource:sourceModel contentModel:taskModel];
                if ([[NSFileManager defaultManager] fileExistsAtPath:targetFilePath]) {
                    existCount ++;
                    NSLog(@"======== 累计: %ld条, 本地任务已存在: %@", existCount, targetFilePath);
                    
                    NSError *removeError = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:targetFilePath error:&removeError];
                    if (removeError) {
                        NSLog(@"======== 删除文件: %@, error: %@", targetFilePath, removeError);
                    } else {
                        NSLog(@"======== 删除文件: %@", targetFilePath);
                    }
                }
            }
            
            progress = (CGFloat)(index + 1) / finishedCount;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (index == finishedCount - 1) {
                    [self.loading hideAnimated:YES];
                    [MBProgressHUD showInfoOnView:self.view WithStatus:@"DataDemo.db解析完成"];
                } else {
                    if (nil == self.loading) {
                        self.loading = [MBProgressHUD showProgressOnView:self.view WithStatus:@"DataDemo.db解析中" progress:progress];
                    }
                    self.loading.progress = progress;
                }
            });
        }
    });
}

#pragma mark - notification
- (void)socketDidConnected:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *host = notification.userInfo[@"host"];
        int port = [notification.userInfo[@"port"] intValue];
        [MBProgressHUD showInfoOnView:AppTool.getAppKeyWindow WithStatus:[NSString stringWithFormat:@"Socket已连接: \n%@, \nport: %d", host, port] afterDelay:1];
        [self reloadData];
    });
}

- (void)socketDidDisConnected:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showInfoOnView:AppTool.getAppKeyWindow WithStatus:@"Socket已断开"];
        [self reloadData];
    });
}


@end
