//
//  PTBAppDelegate.m
//  Biqu
//
//  Created by 闫鹏 on 15/7/13.
//  Copyright (c) 2015年 Taifu Aviation Service Co., Ltd. All rights reserved.
//

#import "PTBAppDelegate.h"
#import "PTBCommonConfigure.h"
#import "PTBMainViewController.h"
#import "PTBHomeActivPicModel.h"
#import "PTBCity.h"
#import "PTBNewAirCompanyModel.h"
#import "PTBAirPortModel.h"
#import <CoreText/CoreText.h>
#import "PPHttpRequestHud.h"
#import "PTBHistoryCityObj.h"
#import <UserNotifications/UserNotifications.h>
#import "PTBShareToFriendsViewController.h"
#import "PTBMineOrderListViewController.h"
#import "PTBUpdateRemindView.h"
#import <Social/Social.h>
#import <WebKit/WebKit.h>
#import "PTBShareCommand.h"

NSString *CITYVERSION  = @"cityVersion";   // 城市信息版本号
NSString *AIRCOMPANYVERSION = @"airCompanyVersion";//航司信息版本号
NSString *AIRPORTCITYVERSION = @"airPortCityVersion";//机场城市信息版本号
NSString *HOLIDAYVERSION = @"holidayVersion";   //节假日版本号
NSString *NATIONVERSION = @"nationVersion";   //国家列表版本号
NSString *AIRLINESHOPVERSION = @"airlineShopVersion";   //航司旗舰店信息版本号

@interface PTBAppDelegate () <PPAlertViewDelegate, UNUserNotificationCenterDelegate>
{
    NSInteger   _notifNumber;
    BOOL        _networkHasBecomeNone;
    NSString *  _version;
    BOOL        _delete;
    BOOL        _isLanching;
}

@property (nonatomic,   copy) NSString * cityCode;
@property (nonatomic,   copy) NSString * picCode;
@property (nonatomic,   copy) NSString * airCompanyCode;
@property (nonatomic,   copy) NSString * airPortCityCode;
@property (nonatomic,   copy) NSString * nationCode;
@property (nonatomic,   copy) NSString * holidayCode;
@property (nonatomic,   copy) NSString * airlineShopCode;   //航司旗舰店信息版本号

@end

@implementation PTBAppDelegate

- (YYDiskCache *)diskCache {
    if (!_diskCache) {
        NSString *path = PPString(@"%@/BaseData", kPPDocumentsPath);
        _diskCache = [[YYDiskCache alloc] initWithPath:path];
    }
    return _diskCache;
}

- (void)resetAllDefaultData {
    [kPPUserDefault setObject:nil forKey:CITYVERSION];
    [kPPUserDefault setObject:nil forKey:HOLIDAYVERSION];
    [kPPUserDefault setObject:nil forKey:CURRENTPICCODE];
    [kPPUserDefault setObject:nil forKey:AIRCOMPANYVERSION];
    [kPPUserDefault setObject:nil forKey:AIRPORTCITYVERSION];
    [kPPUserDefault synchronize];
}

- (void)removeLargeDateBaseWal {
    NSString *path = PPString(@"%@/BaseData", kPPDocumentsPath);
    if (PPFileExist(path)) {
        NSString *removeResult = [kPPUserDefault objectForKey:@"removeOldLargeBaseData"];
        if (![removeResult isEqualToString:@"Y"]) {
            [kPPUserDefault setObject:@"Y" forKey:@"removeOldLargeBaseData"];
            [kPPUserDefault synchronize];
            [kPPFileManager removeItemAtPath:path error:nil];
            [self resetAllDefaultData];
        }
    } else {
        [kPPUserDefault setObject:@"Y" forKey:@"removeOldLargeBaseData"];
        [kPPUserDefault synchronize];
    }
}

- (NSString *)sessionid {if (!_sessionid)  {_sessionid = @"";} return _sessionid;}
- (NSString *)pushToken {if (!_pushToken)  {_pushToken = @"";} return _pushToken;}
- (NSString *)cityCode  {if (!_cityCode)   {_cityCode = @""; } return _cityCode;}
- (NSString *)firstTm   {if (!_firstTm)    {_firstTm = @"";  } return _firstTm;}
-(PTBUserInfo*)userInfo {if (!_userInfo)   {_userInfo = [PTBUserInfo new];} return _userInfo;}
-(NSString*)currentCity {if (!_currentCity){_currentCity = @"北京市";} return _currentCity;}

#pragma mark - 加载首页
- (void)launchingWithRootViewController {
    PTBMainViewController * rootViewController = [[PTBMainViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    __block typeof(rootViewController) blockRootVC = rootViewController;
    if (![self versionCompare] && [self haveGuideImage]) {
        self.window.rootViewController = [PLCommonSet setGuidePageWithImages:@[@"gp_ip4_1@2x.png",@"gp_ip4_2@2x.png",@"gp_ip4_3@2x.png",@"gp_ip6_1@2x.png",@"gp_ip6_2@2x.png",@"gp_ip6_3@2x.png"] pushNextViewController:^{
            [[UIApplication sharedApplication] setStatusBarHidden:NO];
            weakSelf.window.rootViewController = blockRootVC;
        }];
        [kPPUserDefault setBool:YES forKey:@"isLoadGuidePage"];
        [kPPUserDefault synchronize];
    }else{
        self.window.rootViewController = blockRootVC;
    }
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"sessionid"];
    [self.userInfo removeObserver:self forKeyPath:@"alias"];
    [self.userInfo removeObserver:self forKeyPath:@"t"];
    [kPPNoticeCenter removeObserver:self name:MQ_CLIENT_ONLINE_SUCCESS_NOTIFICATION object:nil];
}

#pragma mark - 启动
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.isNeedLogin = YES;
    _isLanching = YES;
    [self removeLargeDateBaseWal];
    [self removeLastVersionHistoryCity];
    [self loadUserInfo];
    if (PP_OS_10_OR_LATER) {
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    }
    [[[PTBCommonConfigure alloc] init] config];
    //添加通知
    [self addNotification];
    //获取基础数据
    [self baseData];
    //网络设置
    [self httpRequestConfigure];
    
    // 判断是否通过推送打开应用
    [self launchingWithRemoteNotif:launchOptions];
    [NSThread sleepForTimeInterval:1];
    [self launchingWithRootViewController];
    
    //添加3D touch
    [PTBCommonConfigure setup3DTouch:application];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    [self.window makeKeyAndVisible];
    return YES;
}
#pragma mark - 添加通知以及通知方法
- (void)addNotification {
    [self addObserver:self forKeyPath:@"sessionid" options:NSKeyValueObservingOptionNew context:NULL];
    [self.userInfo addObserver:self forKeyPath:@"alias" options:NSKeyValueObservingOptionNew context:NULL];
    [self.userInfo addObserver:self forKeyPath:@"t" options:NSKeyValueObservingOptionNew context:NULL];
    // 检测用户成功上线美洽系统
    [kPPNoticeCenter addObserver:self selector:@selector(sendUserInfoToMeiQiaService:) name:MQ_CLIENT_ONLINE_SUCCESS_NOTIFICATION object:nil];
}

- (void)baseData {
    if (![self cityDataFromCache]) {
        //没有缓存,从文件读取
        if (PPFileExist(kCacheCityJsonPath)) {
            NSError * error;
            [kPPFileManager removeItemAtPath:kCacheCityJsonPath error:&error];
        }
        if (PPFileExist(kBundleCityJsonPath) ) {
            NSDictionary *cityDic = [PPFileManager readFromJsonFile:kBundleCityJsonPath];
            NSArray * cityArray = cityDic[@"city"];
            if (cityArray.count > 0) {
                PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
                [dataSource.cityArray removeAllObjects];
                [dataSource.cityArray addObjectsFromArray:cityArray];
                DLog(@"从本地文件添加城市");
            }
        }
    }
    
    if (![self holidayDataFromCache]) {
        if (PPFileExist(kCacheHolidayPath)) {
            NSError *error;
            [kPPFileManager removeItemAtPath:kCacheHolidayPath error:&error];
        }
        if (PPFileExist(kBundleHolidayJsonPath)) {
            NSArray *holidays = (NSArray *)[PPFileManager readFromJsonFile:kBundleHolidayJsonPath];
            PTBCommonDataSource *commonDataSource = [PTBCommonDataSource sharedInstance];
            commonDataSource.holidaysDic = [self getHolidaysDicFromHolidays:holidays];
        }
    }
    /*
     首次运行先把航司和机场城市数据写入，有更新获取到数据之后重新写入
     */
    if (![self airPortCityDataFromCache]) {
        if (PPFileExist(kBundleAirPortCityJsonPath)) {
            NSDictionary * portCityDic = [PPFileManager readFromJsonFile:kBundleAirPortCityJsonPath];
            [self writeAirPortCityDataToYYCache:portCityDic[@"airportCity"]];
            [kPPUserDefault setObject:portCityDic[@"airPortCityVersion"] forKey:AIRPORTCITYVERSION];
            [kPPUserDefault synchronize];
        }
    }
    if (![self airCompanyDataFromCache]) {
        if (PPFileExist(kBundleAirCompanyJsonPath)) {
            NSDictionary * airCompanyDic = [PPFileManager readFromJsonFile:kBundleAirCompanyJsonPath];
            [self writeAirCompanyDataToYYCache:airCompanyDic[@"airline"]];
            [kPPUserDefault setObject:airCompanyDic[@"airCompanyVersion"] forKey:AIRCOMPANYVERSION];
            [kPPUserDefault synchronize];
        }
    }
    
    if (![self airlineShopDataFromCache]) {
        if (PPFileExist(kBundleAirlineShopJsonPath)) {
            NSDictionary * airlineShopDic = [PPFileManager readFromJsonFile:kBundleAirlineShopJsonPath];
            [self writeAirlineShopDataToYYCache:airlineShopDic[@"airlineShop"]];
            [kPPUserDefault setObject:airlineShopDic[@"airlineShopVersion"] forKey:AIRLINESHOPVERSION];
            [kPPUserDefault synchronize];
        }
    }
    
    if (![self nationDataFromCache]) {
        if (PPFileExist(kBundleNationJsonPath) ) {
            NSDictionary *nationDic = [PLCommonTool readFromJSonFile:kBundleNationJsonPath];
            [kPPUserDefault setObject:nationDic[@"nationVersion"] forKey:NATIONVERSION];
            [kPPUserDefault synchronize];
            NSArray * nationArray = nationDic[@"nation"];
            if (nationArray.count > 0) {
                PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
                [dataSource.nationArray removeAllObjects];
                [dataSource.nationArray addObjectsFromArray:nationArray];
                DLog(@"从本地文件添加国家列表");
            }
        }
    }
}

// 判断是否通过推送打开应用
- (void)launchingWithRemoteNotif:(NSDictionary *)launchOptions {
    NSDictionary* remoteNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (remoteNotification) {
        self.isLanchByRemoteNotif = YES;
        [kPPUserDefault setObject:nil forKey:kLastGetMessageTime];
        [kPPUserDefault synchronize];
    } else {
        self.isLanchByRemoteNotif = NO;
    }
}

-(void)loadUserInfo {
    NSDictionary * userInfoDic = (NSDictionary *)[self.diskCache objectForKey:kUserInfoKey];
    if (userInfoDic) {
        [self.userInfo setValuesForKeysWithDictionary:userInfoDic];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"alias"]) {
        PPHttpManager.generalParameters[@"alias"] = self.userInfo.alias;
    } else if ([keyPath isEqualToString:@"t"]) {
        PPHttpManager.generalParameters[@"t"] = self.userInfo.t;
    }
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL  *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    //支付宝登陆/充值回调方法
    if ([url.host isEqualToString:@"safepay"]) {
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            DLog(@"OrderResult = %@",resultDic);
        }];
        //跳转支付宝钱包进行授权，需要将支付宝钱包的授权结果回传给SDK，从SDK中拿authcode和openID
        [[AlipaySDK defaultService] processAuth_V2Result:url standbyCallback:^(NSDictionary *resultDic) {
            DLog(@"AuthResult = %@",resultDic);
        }];
        return YES;
    }
    // 微信支付回调
    if ([url.host isEqualToString:@"pay"]) {
        return [WXApi handleOpenURL:url delegate:self];
    }
    //微信分享回调
    if ([url.absoluteString containsString:WX_AppKey] && [url.host isEqualToString:@"platformId=wechat"]) {
        return [WXApi handleOpenURL:url delegate:ShareCommand];
    }
    //微博分享回调
    if ([url.absoluteString containsString:WB_AppKey] && [url.host isEqualToString:@"response"]) {
        return [WeiboSDK handleOpenURL:url delegate:ShareCommand];
    }

    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    //支付宝登陆/充值回调方法
    if ([url.host isEqualToString:@"safepay"]) {
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            DLog(@"OrderResult = %@",resultDic);
            [kPPNoticeCenter postNotificationName:kNotifAliPayResult object:resultDic];
        }];
        //跳转支付宝钱包进行授权，需要将支付宝钱包的授权结果回传给SDK，从SDK中拿authcode和openID
        [[AlipaySDK defaultService] processAuth_V2Result:url standbyCallback:^(NSDictionary *resultDic) {
            DLog(@"AuthResult = %@",resultDic);
        }];
        return YES;
    }
    // 微信支付回调
    if ([url.host isEqualToString:@"pay"]) {
        return [WXApi handleOpenURL:url delegate:self];
    }
    //微信分享回调
    if ([url.absoluteString containsString:WX_AppKey] && [url.host isEqualToString:@"platformId=wechat"]) {
        return [WXApi handleOpenURL:url delegate:ShareCommand];
    }
    //微博分享回调
    if ([url.absoluteString containsString:WB_AppKey] && [url.host isEqualToString:@"response"]) {
        return [WeiboSDK handleOpenURL:url delegate:ShareCommand];
    }
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    self.pushToken = [XGPush registerDevice:deviceToken successCallback:^{} errorCallback:^{}];
    DLog(@"%@",self.pushToken);
    [self putMesToken];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(nonnull void (^)(UIBackgroundFetchResult))completionHandler {
    DLog(@"%@",userInfo);
    PTBCommonDataSource *commonData = [PTBCommonDataSource sharedInstance];
    commonData.messageCount = 1;
    [kPPUserDefault setObject:nil forKey:kLastGetMessageTime];
    [kPPUserDefault synchronize];
    [kPPNoticeCenter postNotificationName:kNotifReceiveNewMessage object:nil];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    PTBCommonDataSource *commonData = [PTBCommonDataSource sharedInstance];
    commonData.messageCount = 1;
    [kPPUserDefault setObject:nil forKey:kLastGetMessageTime];
    [kPPUserDefault synchronize];
    [kPPNoticeCenter postNotificationName:kNotifReceiveNewMessage object:nil];
}

//在登录、注册成功页面，会发送token至服务器。
//上传pushToken, 用于用户切换登录账号，开关推送设置后，及时收到推送消息
/*
 用户第一次打开时，不允许推送消息，登录成功后，通过设置打开推送消息开关，需要在握手成功后发送token；
 */
- (void)putMesToken {
    if (self.pushToken.pp_isEmpty || self.isNeedLogin) {
        return;
    }
    [PPHttpManager request:kSentPushMessageToken params:@{@"token":self.pushToken,@"deviceType":@"2"} success:^(PPRequest *request, NSDictionary *obj) {
        if ([obj[@"code"] integerValue] == 200) {
            DLog(@"推送token上传成功");
        }else{
            DLog(@"推送token上传失败");
        }
    }];
}

- (void)onResp:(BaseResp*)resp {
    if ([resp isKindOfClass:[PayResp class]]) {
        PayResp *response = (PayResp *)resp;
        switch (response.errCode) {
            case WXSuccess: {
                [kPPNoticeCenter postNotificationName:kNotifWeiXinGotoPaySucceedView object:nil];
            }
                break;
            case WXErrCodeUserCancel:{
                [kPPNoticeCenter postNotificationName:kNotifWeiXinErrCodeUserCancel object:nil];
            }
                break;
            case WXErrCodeUnsupport:
                break;
            default:
                break;
        }
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    if (!_isLanching) { // && !self.isNotNeedRequest
        _isLanching = YES;
        [self requestForHmacKeyAndACK];
        [kPPNoticeCenter postNotificationName:kBecomeActivity object:nil];
    }
    [self clearWebViewCache];
    [self reGetOrderRemindTime];
    [kPPNoticeCenter postNotificationName:kHomePageHoperAnimationBegin object:nil];

}

-(void)clearWebViewCache {
    if (PP_OS_9_OR_LATER) {
        NSSet *types = [NSSet setWithArray:@[WKWebsiteDataTypeDiskCache,
                                             WKWebsiteDataTypeMemoryCache,
                                             WKWebsiteDataTypeOfflineWebApplicationCache,
                                             WKWebsiteDataTypeCookies,
                                             WKWebsiteDataTypeSessionStorage,
                                             WKWebsiteDataTypeWebSQLDatabases,
                                             WKWebsiteDataTypeIndexedDBDatabases]];
        NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:types modifiedSince:dateFrom completionHandler:^{}];
    } else {
        NSString *libraryPath = [PPUtility appLibraryDirectory];
        NSString *cookiesFolderPath = [libraryPath stringByAppendingString:@"/Cookies"];
        [[NSFileManager defaultManager] removeItemAtPath:cookiesFolderPath error:nil];
    }
    
    //清理cookie
    NSHTTPCookieStorage * storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie * cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    //清理cache
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

-(void)applicationWillEnterForeground:(UIApplication *)application {
    _isLanching = NO;
    self.picCode = nil;
    self.cityCode = nil;
    self.airCompanyCode = nil;
    self.firstTm = @"";
    PTBCommonDataSource * commonDataSource = [PTBCommonDataSource sharedInstance];
    commonDataSource.isNeedShowPopWindow = NO;
    [MQManager openMeiqiaService];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [MQManager closeMeiqiaService];
    [kPPNoticeCenter postNotificationName:kHomePageHoperAnimationStop object:nil];
}

#pragma mark - networking
-(void)httpRequestConfigure {
    PPHttp_Manager * manager = PPHttpManager;
    manager.debugBaseUrl   = @"https://mapi.biqu.panatrip.cn/";
    manager.releaseBaseUrl = @"https://mapi.biqu.panatrip.net/";
    NSDictionary * general = @{@"v":[PPUtility deviceUUID],
                               @"t":self.userInfo.t,
                               @"alias":self.userInfo.alias};
    [manager.generalParameters addEntriesFromDictionary:general];
    manager.specialRequestTimeOut = @{kGetHMAC:@(50),kGetPriceCalendar:@(10)};
    manager.specialRequestEncrypt = @{kBaseData:@(PPEncryptNone)};
    manager.errorHandleBlock = ^(NSError * error){
        DLog(@"%@",error.description);
    };
    PPWeakSelf;
    manager.serverCodeHandle = ^(NSInteger code, NSString * msg) {
        switch (code) {
            case 200:
            case 400:
            case 401:
            case 406:
            case 407:
            case 413:
            case 414:
            case 415:
            case 417:
            case 999:
                break;
            case 402: {
                if (PPNonNullString(msg)) {
                    kPLAlertShow(msg);
                } else {
                    kPLAlertShow(kPTB_requestTimeOut);
                }
            }
                break;
            case 403: {
                kPLAlertShow(kPTB_invaildRequest);
            }
                break;
            case 404:
                break;
            case 408:
            case 409: {
                [weakSelf requestForHmacKeyAndACK];
            }
                break;
            default: {
                if (msg.length > 0) {
                    kPLAlertShow(msg);
                }
            }
                break;
        }
    };
    //检测网络状态_1117
    [PPReachability reachability].networkChangedBlock = ^(PPReachability *reach) {
        [weakSelf reachabilityStatuChange:reach];
    };
    
    if ([[PPReachability reachability] status] == PPReachabilityStatusNone) {
        _networkHasBecomeNone = YES;
    } else {
        [self requestForInfomation];
    }
}

- (void)reachabilityStatuChange:(PPReachability *)reach {
    if (reach.status == PPReachabilityStatusNone) {
        _networkHasBecomeNone = YES;
    } else {
        if (_networkHasBecomeNone) {
            _networkHasBecomeNone = NO;
            [self requestForInfomation];
        }
    }
}

-(void)requestForInfomation {
    [self requestForHmacKey:YES];
}

-(void)requestForHmacKeyAndACK {
    [self requestForHmacKey:NO];
}

-(void)requestForOtherInfomation {
    [self requestSystemConfig];
    [self requestForGiveInsurer];
    [self requestOrderPostage];
    [self requestForCityList:self.cityCode];
    [self requestForNationList:self.nationCode];
    [self requestForHolidayInfo:self.holidayCode];
    [self requestForPicList:self.picCode];
    [self requestForPopWindowContent];
    [self requestForBaseDataAirportCity];
    [self requestForBaseDataAirCompany];
    [self requestForBaseDataAirlineShop];
}

#pragma mark 获取HMAC密钥
- (void)requestForHmacKey:(BOOL)isNeedOtherInfo {
    DLog(@"hmac");
    PPBlockSelf;
    PPWeakSelf;
    [PPHttpManager request:kGetHMAC params:nil success:^(PPRequest *request, NSDictionary *obj) {
        if ([obj[@"code"] integerValue] == 200) {
            blockSelf.sessionid = obj[@"desc"];
            blockSelf.firstTm = @"";
            [kPPNoticeCenter postNotificationName:kNotifHiddenHomeAlert object:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf requestForACK:isNeedOtherInfo];
            });
        } else {
            [NSThread sleepForTimeInterval:3];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf requestForHmacKey:isNeedOtherInfo];
            });
        }
    } failure:^(PPRequest *request, NSError *error) {
        [NSThread sleepForTimeInterval:3];
        dispatch_async(dispatch_get_main_queue(), ^{
            DLog(@"%@",error.description);
            blockSelf.firstTm = @"";
            [weakSelf requestForHmacKey:isNeedOtherInfo];
        });
    }];
}

#pragma mark 握手请求
-(void)requestForACK:(BOOL)isNeedOtherInfo {
    PPWeakSelf;
    __block typeof(self) blockSelf = self;
    NSString * currentVersion = [[PPUtility appVersion] pp_replaceByString:@"2" range:NSMakeRange(0, 1)];
    NSString * model = [PPUtility deviceModel];
    [PPHttpManager request:kACKnowledgement params:@{@"version":currentVersion,@"model":model,@"p":@"i",@"channel":@"AppStore"} success:^(PPRequest *request, NSDictionary *obj) {
        if ([obj[@"code"] integerValue] == 200) {
            blockSelf.cityCode = obj[@"newCityCode"];
            blockSelf.picCode = obj[@"picCode"];
            blockSelf.airCompanyCode = obj[@"airlineCode"];
            blockSelf.nationCode = obj[@"nationCode"];
            blockSelf.holidayCode = obj[@"holidayCode"];
            blockSelf.airlineShopCode = obj[@"airlineShopCode"];
            //机场城市的code使用 机场code+城市code，任何一个code改变，机场城市都要更新
            blockSelf.airPortCityCode = [NSString stringWithFormat:@"%@%@",obj[@"airportCode"],obj[@"newCityCode"]];
            if (_isLanchByRemoteNotif) {
                [kPPNoticeCenter postNotificationName:kNotifOpenByRemoteNotif object:nil];
            }
            if ([obj[@"login"] isEqualToString:@"1"]) {
                blockSelf.isNeedLogin = NO;
                [weakSelf putMesToken];
                [kPPNoticeCenter postNotificationName:kNotifIsNotNeedLog object:nil];
            }else if ([obj[@"login"] isEqualToString:@"2"]) {
                blockSelf.isNeedLogin = YES;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf requestForUpgrade];
                if (isNeedOtherInfo) {
                    [weakSelf requestForOtherInfomation];
//                    [weakSelf requestForPaymentInfo];
                }
            });
        }
    }];
}

#pragma mark 检测版本更新
-(void)analysisForUpdateDic:(NSDictionary *)dic {
//    DLog(@"%@",dic);
    NSString *remarkDateStr = [kPPUserDefault valueForKey:kUpdateRemarkDate];
    NSString *currentDateStr = [[NSDate date] pp_descriptionWithFormatter:@"yyyyMMdd"];
    BOOL isCanUpdate = NO;
    if (!PPNonNullString(remarkDateStr) || ![remarkDateStr isEqualToString:currentDateStr]) {
        isCanUpdate = YES;
    }
    NSString * sVersion = dic[@"version"];
    if (!sVersion || [sVersion isEqualToString:@""]) {
        sVersion = [PPUtility appVersion];
    }
    if ([self compareForServiceVersion:sVersion]) {
        if ([dic[@"update"] boolValue]) {
            NSString *updateContent = PPString(@"更新内容：\n%@", dic[@"versionText"]);;
            NSString *updateVersion = PPString(@"最新版本：%@", [sVersion pp_replaceByString:@"2" range:NSMakeRange(0, 1)]);
            BOOL isForce = [dic[@"force"] boolValue];
            PTBUpdateRemindView *updateView = [[PTBUpdateRemindView alloc] initWithVersion:updateVersion updateContent:updateContent isForce:isForce];
            [updateView setClickUpdateButton:^{
                NSURL *url = [NSURL URLWithString:@"https://itunes.apple.com/cn/app/id1007060050?mt=8"];
                if ([[UIApplication sharedApplication] canOpenURL:url]) {
                    [[UIApplication sharedApplication] openURL:url];
                }
            }];
            if (isForce) {
                [updateView show];
            } else {
                if (isCanUpdate) {
                    [kPPUserDefault setValue:currentDateStr forKey:kUpdateRemarkDate];
                    [kPPUserDefault synchronize];
                    [updateView show];
                }
            }
        }
    }
}

-(BOOL)compareForServiceVersion:(NSString *)sVersion {
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    NSString *currentVersion = [infoDic objectForKey:@"CFBundleShortVersionString"];

    if ([sVersion pp_containsString:@"."]) {
        if ([sVersion compare:currentVersion options:NSNumericSearch] == NSOrderedDescending) {
            return YES;
        } else {
            return NO;
        }
    } else {
        currentVersion = [currentVersion stringByReplacingOccurrencesOfString:@"." withString:@""];
        if([currentVersion compare:sVersion] != NSOrderedSame) {
            return YES;
        }
        return NO;
    }
}

- (void)ppAlertView:(UIView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag==10000) {
        if (buttonIndex == 0) {
            NSURL *url = [NSURL URLWithString:@"https://itunes.apple.com/cn/app/id1007060050?mt=8"];
            [[UIApplication sharedApplication] openURL:url];
        }
    }else if(alertView.tag==10001) {
        if (buttonIndex == 1) {
            NSURL *url = [NSURL URLWithString:@"https://itunes.apple.com/cn/app/id1007060050?mt=8"];
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}

- (BOOL)versionCompare {
    NSString * storeCurrentVersion = [kPPUserDefault objectForKey:@"currentVersion"];
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    NSString *currentVersion = [infoDic objectForKey:@"CFBundleShortVersionString"];
    BOOL res = NO;
    if (![storeCurrentVersion isEqualToString:currentVersion]) {
        [kPPUserDefault setObject:currentVersion forKey:@"currentVersion"];
        [kPPUserDefault synchronize];
    }else{
        res = YES;
    }
    return res;
}

- (BOOL)haveGuideImage {
    NSString *guideImagePath = [[NSBundle mainBundle] pathForResource:@"gp_ip4_1@2x" ofType:@"png"];
    return PPNonNullString(guideImagePath);
}

- (NSString *)getVersionStringForNewFormat:(NSString *)version {
    NSArray * strings = [version componentsSeparatedByString:@"."];
    NSString * newString = @"";
    if (strings.count > 2) {
        newString = [NSString stringWithFormat:@"%@.%@",strings[0],strings[1]];
    }else{
        return version;
    }
    return newString;
}

#pragma mark - 把国家数据写入YYCache
- (void)writeNationDataToYYCache:(NSArray *)array {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (array.count > 0) {
            PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
            [dataSource.nationArray removeAllObjects];
            [dataSource.nationArray addObjectsFromArray:array];
            DLog(@"把国家数据写入YYCache");
            [self.diskCache setObject:array forKey:kNationKey];
        }
    });
}

#pragma mark - 把城市数据写入YYCache
- (void)writeCityDataToYYCache:(NSArray *)array {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (array.count > 0) {
            PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
            [dataSource.cityArray removeAllObjects];
            [dataSource.cityArray addObjectsFromArray:array];
            DLog(@"把城市数据写入YYCache");
            [self.diskCache setObject:array forKey:kCityKey];
        }
    });
}

//更新历史城市数据
- (void)updateHistorySearchCity:(NSArray *)array {
    //国际历史城市
    NSArray * historyCities_g = [kPPUserDefault objectForKey:@"historyCities_g"];
    if (historyCities_g.count > 0){
        NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:10];
        for (NSDictionary *dic in historyCities_g) {
            PTBHistoryCityObj *historycity = [PTBHistoryCityObj mj_objectWithKeyValues:dic];
            NSString * cityName = historycity.cityName;
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name like %@", cityName];
            NSArray * result = [array filteredArrayUsingPredicate:predicate];
            if (result.count > 0) {
                NSDictionary * cityDict = result[0];
                historycity.cityCode = cityDict[@"threeWord"];
                [mutableArray addObject:historycity];
            }
        }
        NSArray * historyCities = [PTBHistoryCityObj mj_keyValuesArrayWithObjectArray:mutableArray];
        [kPPUserDefault setObject:historyCities forKey:@"historyCities_g"];
        [kPPUserDefault synchronize];
    }
    
    //国内城市
    NSArray * historyCities_c = [kPPUserDefault objectForKey:@"historyCities_c"];
    if (historyCities_c.count > 0){
        NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:10];
        for (NSDictionary *dic in historyCities_c) {
            PTBHistoryCityObj *historycity = [PTBHistoryCityObj mj_objectWithKeyValues:dic];
            NSString * cityName = historycity.cityName;
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name like %@", cityName];
            NSArray * result = [array filteredArrayUsingPredicate:predicate];
            if (result.count > 0) {
                NSDictionary * cityDict = result[0];
                historycity.cityCode = cityDict[@"threeWord"];
                [mutableArray addObject:historycity];
            }
        }
        NSArray * historyCities = [PTBHistoryCityObj mj_keyValuesArrayWithObjectArray:mutableArray];
        [kPPUserDefault setObject:historyCities forKey:@"historyCities_c"];
        [kPPUserDefault synchronize];
    }
}
#pragma mark - 从YYCache读取城市数据
- (BOOL)cityDataFromCache {
    NSArray * cityInfoArray = (NSArray *)[self.diskCache objectForKey:kCityKey];
    if (cityInfoArray.count > 0) {
        PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
        [dataSource.cityArray removeAllObjects];
        [dataSource.cityArray addObjectsFromArray:cityInfoArray];
        DLog(@"从YYCache读取城市数据");
        return YES;
    }
    return NO;
}

#pragma mark - 从YYCache读取国家数据(乘机人国籍)
- (BOOL)nationDataFromCache {
    NSArray * nationArray = (NSArray *)[self.diskCache objectForKey:kNationKey];
    if (nationArray.count > 0) {
        PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
        [dataSource.nationArray removeAllObjects];
        [dataSource.nationArray addObjectsFromArray:nationArray];
        DLog(@"从YYCache读取国家数据");
        return YES;
    }
    return NO;
}
#pragma mark - 从YYCache读取节假日数据
- (BOOL)holidayDataFromCache {
    id holidayData = [self.diskCache objectForKey:kHolidayKey];
    if ([holidayData isKindOfClass:[NSDictionary class]]) {
        PTBCommonDataSource * commonDataSource = [PTBCommonDataSource sharedInstance];
        commonDataSource.holidaysDic = holidayData;
        return YES;
    } else if ([holidayData isKindOfClass:[NSArray class]]){
        [self.diskCache removeObjectForKey:kHolidayKey];
        return NO;
    }
    return NO;
}
#pragma mark 节假日格式转换
- (NSDictionary *)getHolidaysDicFromHolidays:(NSArray *)holidays {
    NSMutableDictionary *holidaysDic = [NSMutableDictionary dictionary];
    for (NSDictionary * holiday in holidays) {
        NSDate *dateKey = [NSDate pp_dateFromString:holiday[@"sdate"] format:@"yyyy-MM-dd"];
        [holidaysDic setObject:holiday forKey:dateKey];
    }
    return holidaysDic;
}
#pragma mark 获取国家列表数据
- (void)requestForNationList:(NSString *)nationCode {
    
    NSString *version = [kPPUserDefault objectForKey:NATIONVERSION];
    if (!PPNonNullString(version)) {
        version = @"";
        if (PPFileExist(kBundleNationJsonPath)) {
            NSDictionary *nationDic = [PLCommonTool readFromJSonFile:kBundleNationJsonPath];
            version = nationDic[@"nationVersion"];
        }
    }
    if ([version compare:nationCode] == NSOrderedAscending || !PPNonNullString(version)) {
        PPWeakSelf;
        [PPHttpManager request:kBaseData params:@{@"type":@"6"} success:^(PPRequest *request, NSDictionary *obj) {
            if ([obj[@"code"] integerValue] == 200) {
                //20170527165449
//                [self writeFile:obj toPath:PPString(@"%@/nation.json", kPPDocumentsPath)];
                NSArray *nationArray = obj[@"nation"];
                if (nationArray.count > 0) {
                    [kPPUserDefault setObject:nationCode forKey:NATIONVERSION];
                    [kPPUserDefault synchronize];
                    [weakSelf writeNationDataToYYCache:nationArray];
                }
            }
        }];
    } else {
        if (![self nationDataFromCache]) {
            if (PPFileExist(kBundleNationJsonPath) ) {
                NSDictionary *nationDic = [PLCommonTool readFromJSonFile:kBundleNationJsonPath];
                [kPPUserDefault setObject:nationDic[@"nationVersion"] forKey:NATIONVERSION];
                [kPPUserDefault synchronize];
                [self.diskCache setObject:nationDic[@"nation"] forKey:kNationKey];
            }
        }
    }
}

#pragma mark 获取城市列表数据
- (void)requestForCityList:(NSString *)cityCode {
    PPWeakSelf;
    NSString *version = [kPPUserDefault objectForKey:CITYVERSION];
    if (!PPNonNullString(version)) {
        version = @"";
        if (PPFileExist(kBundleCityJsonPath)) {
            NSDictionary *cityDic = [PLCommonTool readFromJSonFile:kBundleCityJsonPath];
            version = cityDic[@"cityVersion"];
        }
    }
    if ([version compare:cityCode] == NSOrderedAscending) {
        [PPHttpManager request:kBaseData params:@{@"type":@"1"} success:^(PPRequest *request, NSDictionary *obj) {
            if ([obj[@"code"] integerValue] == 200) {
                //20170824182641
//                [self writeFile:obj toPath:kCacheCityJsonPath];
                NSArray *cityArray = obj[@"city"];
                if (cityArray.count > 0) {
                    [kPPUserDefault setObject:cityCode forKey:CITYVERSION];
                    [kPPUserDefault synchronize];
                    [weakSelf writeCityDataToYYCache:cityArray];
                    [weakSelf updateHistorySearchCity:cityArray];
                }
            }
        }];
    }
    else {
        if (![self cityDataFromCache]) {
            if (PPFileExist(kBundleCityJsonPath) ) {
                NSDictionary *cityDic = [PLCommonTool readFromJSonFile:kBundleCityJsonPath];
                [kPPUserDefault setObject:cityDic[@"cityVersion"] forKey:CITYVERSION];
                [kPPUserDefault synchronize];
                [self.diskCache setObject:cityDic[@"city"] forKey:kCityKey];
            }
        }
    }
}

#pragma mark 获取节假日信息
-(void)requestForHolidayInfo:(NSString *)holidayCode {
    NSString * version = [kPPUserDefault objectForKey:HOLIDAYVERSION];
    if (!version) {
        version = @"";
    }
    NSString * dateStr = [[NSDate date] pp_descriptionWithFormatter:@"yyyyMM"];
    PPWeakSelf;
    if ([version compare:holidayCode] == NSOrderedAscending) {
        [PPHttpManager request:kGetHolidayInfo params:@{@"version":dateStr} success:^(PPRequest *request, NSDictionary *obj) {
            if ([obj[@"code"] integerValue] == 200) {
//                [self writeFile:obj toPath:kCacheHolidayPath];
                NSArray * holidays = obj[@"holidays"];
                if (holidays.count > 0) {
                    [kPPUserDefault setObject:holidayCode forKey:HOLIDAYVERSION];
                    [kPPUserDefault synchronize];
                    PTBCommonDataSource * commonDataSource = [PTBCommonDataSource sharedInstance];
                    commonDataSource.holidaysDic = [weakSelf getHolidaysDicFromHolidays:holidays];
                    [weakSelf.diskCache setObject:commonDataSource.holidaysDic forKey:kHolidayKey];
                }
            }
        }];
    } else {
        if (![self holidayDataFromCache]) {
            if (PPFileExist(kBundleHolidayJsonPath)) {
                NSArray *holidays = (NSArray *)[PPFileManager readFromJsonFile:kBundleHolidayJsonPath];
                [self.diskCache setObject:[self getHolidaysDicFromHolidays:holidays] forKey:kHolidayKey];
            }
        }
    }
}

#pragma mark 获取首页活动图片
- (void)requestForPicList:(NSString *)picCode{
    NSString *currentPicCode = [kPPUserDefault valueForKey:CURRENTPICCODE];
    if (currentPicCode == nil) {
        currentPicCode = @"";
    }
    PPWeakSelf;
    if ([currentPicCode compare:picCode] == NSOrderedAscending) {
        // 获取最新活动图片
        NSString * version = [[PPUtility appVersion] pp_replaceByString:@"2" range:NSMakeRange(0, 1)];
        [PPHttpManager request:kGetHomePic params:@{@"platform":@"2", @"version":version} success:^(PPRequest *request, NSDictionary *obj) {
            if ([obj[@"code"] integerValue] == 200) {
                NSArray *pics = obj[@"pics"];
                NSMutableArray * picArray = [[PTBCommonDataSource sharedInstance] picArray];
                [picArray removeAllObjects];
                if (pics.count > 0) {
                    NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:10];
                    for (NSDictionary *dic in pics) {
                        PTBHomeActivPicModel *picModel = [[PTBHomeActivPicModel alloc] init];
                        [picModel setValuesForKeysWithDictionary:dic];
                        [mutableArray addObject:picModel];
                    }
                    [picArray addObjectsFromArray:mutableArray];
                    DLog(@"添加图片");
                    [picArray insertObject:mutableArray.lastObject atIndex:0];
                    [picArray addObject:mutableArray.firstObject];
                }
                [weakSelf.diskCache setObject:pics forKey:kPictureKey];
                [kPPNoticeCenter postNotificationName:kNotifGetHomePic object:nil];
                [kPPUserDefault setValue:picCode forKey:CURRENTPICCODE];
                [kPPUserDefault synchronize];
            }
        }];
    }
}

#pragma mark popwimdow
- (void)requestForPopWindowContent {
    PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
    if (!dataSource.isNeedShowPopWindow) {
        [PPHttpManager request:kPopWindow params:nil success:^(PPRequest *request, NSDictionary *obj) {
            DLog(@"%@",obj);
            if ([obj[@"code"] integerValue] == 200) {
                if (PPNonNullString(((NSString *)obj[@"content"]))) {
                    dataSource.isNeedShowPopWindow = YES;
                    dataSource.popWindowContent = obj[@"content"];
                    [kPPNoticeCenter postNotificationName:kNotifShowPopWindow object:nil];
                }
            }
        }];
    }
}

#pragma mark - 获取收银台所需信息
- (void)requestForPaymentInfo {
    PTBCommonDataSource *dataSource = [PTBCommonDataSource sharedInstance];
    NSString *currentDate = [NSDate date].pp_descriptionYMD;
    // 获取信用卡列表
    NSDictionary *creditBankDic = (NSDictionary *)[self.diskCache objectForKey:kCreditBanksKey];
    BOOL canRequestCreditBank = YES;
    if (creditBankDic) {
        NSString *saveDate = [creditBankDic objectForKey:CURRENTDATE];
        if (PPNonNullString(saveDate) && [saveDate isEqualToString:currentDate]) {
            NSArray *creditBankArray = [creditBankDic objectForKey:CREDITBANKS];
            if (creditBankArray.count > 0) {
                canRequestCreditBank = NO;
                dataSource.creditBanks = creditBankArray;
            }
        }
    }
    if (canRequestCreditBank) {
        [self getCreditBanksFromServer];
    }
    
    // 获取储蓄卡列表
    NSDictionary *savingBankDic = (NSDictionary *)[self.diskCache objectForKey:kSavingBanksKey];
    BOOL canRequestSavingBank = YES;
    if (savingBankDic) {
        NSString *saveDate = [savingBankDic objectForKey:CURRENTDATE];
        if (PPNonNullString(saveDate) && [saveDate isEqualToString:currentDate]) {
            NSArray *savingBankArray = [savingBankDic objectForKey:SAVINGBANKS];
            if (savingBankArray.count > 0) {
                canRequestSavingBank = NO;
                dataSource.savingBanks = savingBankArray;
            }
        }
    }
    if (canRequestSavingBank) {
        [self getSavingBanksFromServer];
    }

    // 获取证件类型列表
    NSDictionary *credTypesDic = (NSDictionary *)[self.diskCache objectForKey:kCredTypesKey];
    BOOL canRequestCredTypes = YES;
    if (credTypesDic) {
        NSString *saveDate = [credTypesDic objectForKey:CURRENTDATE];
        if (PPNonNullString(saveDate) && [saveDate isEqualToString:currentDate]) {
            NSDictionary *tmpCredTypesDic = [credTypesDic objectForKey:CREDTYPES];
            if (tmpCredTypesDic.count > 0) {
                canRequestCredTypes = NO;
                dataSource.credTypeDic = tmpCredTypesDic;
            }
        }
    }
    if (canRequestCredTypes) {
        [self getCredTypesFromServer];
    }
}

#pragma mark 获取信用卡列表
- (void)getCreditBanksFromServer{
    PPWeakSelf;
    [PPHttpManager request:kGetCreditBankList params:nil success:^(PPRequest *request, NSDictionary *obj) {
        if ([obj[@"code"] integerValue] == 200) {
            NSArray *list = obj[@"list"];
            PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
            dataSource.creditBanks = list;
            NSString *nowDate = [NSDate date].pp_descriptionYMD;
            NSDictionary *cacheDic = [NSDictionary dictionaryWithObjectsAndKeys:list,CREDITBANKS,
                                      nowDate, CURRENTDATE, nil];
            [weakSelf.diskCache setObject:cacheDic forKey:kCreditBanksKey];
        }
    }];
}
#pragma mark 获取储蓄卡列表
- (void)getSavingBanksFromServer{
    PPWeakSelf;
    [PPHttpManager request:kGetSavingBankList params:nil success:^(PPRequest *request, NSDictionary *obj) {
        if ([obj[@"code"] integerValue] == 200) {
            NSArray *list = obj[@"list"];
            PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
            dataSource.savingBanks = list;
            NSString *nowDate = [NSDate date].pp_descriptionYMD;
            NSDictionary *cacheDic = [NSDictionary dictionaryWithObjectsAndKeys:list,SAVINGBANKS,
                                      nowDate, CURRENTDATE, nil];
            [weakSelf.diskCache setObject:cacheDic forKey:kSavingBanksKey];
        }
    }];
}

#pragma mark 获取收银台证件类型
- (void)getCredTypesFromServer{
    PPWeakSelf;
    [PPHttpManager request:kGetCredtypeList params:nil success:^(PPRequest *request, NSDictionary *obj) {
        if (obj) {
            NSDictionary *dic = obj[@"map"];
            if (dic) {
                PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
                dataSource.credTypeDic = dic;
                NSString *nowDate = [NSDate date].pp_descriptionYMD;
                NSDictionary *cacheDic = [NSDictionary dictionaryWithObjectsAndKeys:dic,CREDTYPES,
                                          nowDate, CURRENTDATE, nil];
                [weakSelf.diskCache setObject:cacheDic forKey:kCredTypesKey];
            }
        }
    }];
}

#pragma mark - 获取基础数据
- (void)requestForBaseDataCity {
    // type: 1城市, 2机场, 3航司, 4城市机场, 5机场城市, 6国家;
    [PPHttpManager request:kBaseData params:@{@"type":@"1"} success:^(PPRequest *request, NSDictionary *obj) {
        DLog(@"%@", obj);
        if ([obj[@"code"] integerValue] == 200) {
            NSArray *cityArray = obj[@"city"];
            [PPFileManager writeToJsonFile:cityArray path:kCacheCityJsonPath complete:^(NSString *path, BOOL success) {
                if (success) {DLog(@"写入成功");}
            }];
        }
    }];
}

#pragma mark - 获取机场城市数据
- (void)requestForBaseDataAirportCity {
    PPWeakSelf;
    NSString *version = [kPPUserDefault objectForKey:AIRPORTCITYVERSION];
    if (!PPNonNullString(version)) {
        version = @"";
        if (PPFileExist(kBundleAirPortCityJsonPath))  {
            NSDictionary * portCityDic = [PPFileManager readFromJsonFile:kBundleAirPortCityJsonPath];
            version = portCityDic[@"airPortCityVersion"];
        }
    }
    if ([version compare:self.airPortCityCode] == NSOrderedAscending) {
        // type: 1城市, 2机场, 3航司, 4城市机场, 5机场城市;
        [PPHttpManager request:kBaseData params:@{@"type":@"5"} success:^(PPRequest *request, NSDictionary *obj) {
            if ([obj[@"code"] integerValue] == 200) {
                NSArray *airPortArray = obj[@"airportCity"];
                //test  version:2017082418273120170824182641
//                [self writeFile:airPortArray toPath:PPString(@"%@/airPortCity.json", kPPDocumentsPath)];
                [weakSelf writeAirPortCityDataToYYCache:airPortArray];
                [kPPUserDefault setObject:weakSelf.airPortCityCode forKey:AIRPORTCITYVERSION];
                [kPPUserDefault synchronize];
            }
        }];
        return;
    }
    if (![self airPortCityDataFromCache]) {
        if (PPFileExist(kBundleAirPortCityJsonPath)) {
            NSDictionary * portCityDic = [PLCommonTool readFromJSonFile:kBundleAirPortCityJsonPath];
            [self writeAirPortCityDataToYYCache:portCityDic[@"airportCity"]];
            [kPPUserDefault setObject:portCityDic[@"airPortCityVersion"] forKey:AIRPORTCITYVERSION];
            [kPPUserDefault synchronize];
        }
    }
}
#pragma mark 把机场城市数据写入YYCache
- (void)writeAirPortCityDataToYYCache:(NSArray *)array {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (array.count > 0) {
            //把每个机场以id为key保存到YYCache
            NSMutableDictionary *mutableDic = [NSMutableDictionary dictionaryWithCapacity:10];
            for (NSDictionary * portDic in array) {
//                PTBAirPortModel * model = [[PTBAirPortModel alloc]init];
//                [model setValuesForKeysWithDictionary:portDic];
                //机场三字码作为Key
//                [self.diskCache setObject:model forKey:portDic[@"threeWord"]];
                if (PPNonNullString(PPString(@"%@", portDic[@"threeWord"]))) {
                    [mutableDic setObject:portDic forKey:portDic[@"threeWord"]];
                }
            }
            [self.diskCache setObject:mutableDic forKey:kAirPortCitysKey];
        }
    });
}

#pragma mark 从YYCache读取机场城市数据
- (BOOL)airPortCityDataFromCache {
    NSString *version = [kPPUserDefault objectForKey:AIRPORTCITYVERSION];
    if (version) {
        return YES;
    }
    return NO;
}

#pragma mark - 获取航司数据
- (void)requestForBaseDataAirCompany {
    PPWeakSelf;
    NSString *version = [kPPUserDefault objectForKey:AIRCOMPANYVERSION];
    if (!PPNonNullString(version)) {
        version = @"";
        if (PPFileExist(kBundleAirCompanyJsonPath))  {
            NSDictionary * portDic = [PLCommonTool readFromJSonFile:kBundleAirCompanyJsonPath];
            version = portDic[@"airCompanyVersion"];
        }
    }
    if ([version compare:self.airCompanyCode] == NSOrderedAscending) {
        // type: 1城市, 2机场, 3航司, 4城市机场, 5机场城市;
        [PPHttpManager request:kBaseData params:@{@"type":@"3"} success:^(PPRequest *request, NSDictionary *obj) {
            if ([obj[@"code"] integerValue] == 200) {
                NSArray *airCompanyArray = obj[@"airline"];
                //test  version:20170821160712
//                [self writeFile:airCompanyArray toPath:kCacheAirCompanyJsonPath];
                [weakSelf writeAirCompanyDataToYYCache:airCompanyArray];
                [kPPUserDefault setObject:weakSelf.airCompanyCode forKey:AIRCOMPANYVERSION];
                [kPPUserDefault synchronize];
            }
        }];
        return;
    }
    if (![self airCompanyDataFromCache]) {
        if (PPFileExist(kBundleAirCompanyJsonPath)) {
            NSDictionary * airCompanyDic = [PPFileManager readFromJsonFile:kBundleAirCompanyJsonPath];
            [self writeAirCompanyDataToYYCache:airCompanyDic[@"airline"]];
            [kPPUserDefault setObject:airCompanyDic[@"airCompanyVersion"] forKey:AIRCOMPANYVERSION];
            [kPPUserDefault synchronize];
        }
    }
}

#pragma mark 从YYCache读取航司数据
- (BOOL)airCompanyDataFromCache {
    NSString *version = [kPPUserDefault objectForKey:AIRCOMPANYVERSION];
    if (version) {
        return YES;
    }
    return NO;
}

#pragma mark 把航司数据写入YYCache
- (void)writeAirCompanyDataToYYCache:(NSArray *)array {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (array.count > 0) {
            //把每个航司以code为key保存到YYCache
            NSMutableDictionary *mutableDic = [NSMutableDictionary dictionaryWithCapacity:10];
            for (NSDictionary * companyDic in array) {
//                PTBNewAirCompanyModel * companyModel = [[PTBNewAirCompanyModel alloc]init];
//                [companyModel setValuesForKeysWithDictionary:companyDic];
//                [self.diskCache setObject:companyModel forKey:companyDic[@"code"]];
                if (PPNonNullString(PPString(@"%@", companyDic[@"code"]))) {
                    [mutableDic setObject:companyDic forKey:companyDic[@"code"]];
                }
            }
            [self.diskCache setObject:mutableDic forKey:kAirCompanysKey];
        }
    });
}

#pragma mark - 获取航司旗舰店
- (void)requestForBaseDataAirlineShop {
    PPWeakSelf;
    NSString *version = [kPPUserDefault objectForKey:AIRLINESHOPVERSION];
    if (!PPNonNullString(version)) {
        version = @"";
        if (PPFileExist(kBundleAirlineShopJsonPath))  {
            NSDictionary * airlineDic = [PLCommonTool readFromJSonFile:kBundleAirlineShopJsonPath];
            version = airlineDic[@"airlineShopVersion"];
        }
    }
    if ([version compare:self.airlineShopCode] == NSOrderedAscending) {
        [PPHttpManager request:kBaseData params:@{@"type":@"7"} success:^(PPRequest *request, NSDictionary *obj) {
            if ([obj[@"code"] integerValue] == 200) {
                NSArray *airlineShopArray = obj[@"airlineShop"];
                //test  version:20170821160712
//                [weakSelf writeFile:airlineShopArray toPath:kCacheAirlineShopJsonPath];
                [weakSelf writeAirlineShopDataToYYCache:airlineShopArray];
                [kPPUserDefault setObject:weakSelf.airlineShopCode forKey:AIRLINESHOPVERSION];
                [kPPUserDefault synchronize];
            }
        }];
    }
}

#pragma mark 把航司旗舰店数据写入YYCache
- (void)writeAirlineShopDataToYYCache:(NSArray *)array {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (array.count > 0) {
            //把每个航司以code为key保存到YYCache
            NSMutableDictionary *mutableDic = [NSMutableDictionary dictionaryWithCapacity:10];
            for (NSDictionary * airlineShopDic in array) {
                if (PPNonNullString(PPString(@"%@", airlineShopDic[@"code"]))) {
                    [mutableDic setObject:airlineShopDic forKey:airlineShopDic[@"code"]];
                }
            }
            [self.diskCache setObject:mutableDic forKey:kAirlineShopsKey];
        } else {
            [self.diskCache removeObjectForKey:kAirlineShopsKey];
        }
    });
}

#pragma mark 从YYCache读取航司数据
- (BOOL)airlineShopDataFromCache {
    NSString *version = [kPPUserDefault objectForKey:AIRLINESHOPVERSION];
    return PPNonNullString(version);
}

#pragma mark - 上传用户信息, 用于展示给客服
- (void)sendUserInfoToMeiQiaService:(NSNotification *)notif {
    NSDictionary * userInfoDic = (NSDictionary *)[self.diskCache objectForKey:kUserInfoKey];
    if (!self.isNeedLogin && userInfoDic.count > 0) {
        PTBUserInfo *userInfo = [[PTBUserInfo alloc] init];
        [userInfo setValuesForKeysWithDictionary:userInfoDic];
        NSDictionary *meiQiaParams = @{@"name":userInfo.name,@"tel":userInfo.phone};
        [MQManager setClientInfo:meiQiaParams completion:^(BOOL success, NSError *error) {
            if (success) {
                DDLog(@"上传信息至美洽成功");
            }
        }];
    }
}

#pragma mark - 删除城市列表中的历史城市
- (void)removeLastVersionHistoryCity {
    NSString *isRemoveLastVersionHistoryCity = [kPPUserDefault objectForKey:kRemoveLastVersionHistoryCity];
    if (!(isRemoveLastVersionHistoryCity && [isRemoveLastVersionHistoryCity isEqualToString:@"Y"])) {
        [kPPUserDefault removeObjectForKey:@"historyCities_c"];
        [kPPUserDefault removeObjectForKey:@"historyCities_g"];
        [kPPUserDefault setObject:@"Y" forKey:kRemoveLastVersionHistoryCity];
        [kPPUserDefault synchronize];
    }
    
    NSString *isRemoveHomePageSearchInfo = [kPPUserDefault objectForKey:kRemoveHomePageSearchInfo];
    if (!(isRemoveHomePageSearchInfo && [isRemoveHomePageSearchInfo isEqualToString:@"Y"])) {
        [kPPUserDefault removeObjectForKey:kLastSearchInfoStr];
        [kPPUserDefault setObject:@"Y" forKey:kRemoveHomePageSearchInfo];
        [kPPUserDefault synchronize];
    }
}

#pragma mark - 获取配置信息
- (void)requestSystemConfig {
    PPWeakSelf;
    [PPHttpManager request:kConfig params:nil success:^(PPRequest *request, NSDictionary *obj) {
        DLog(@"SystemConfig:%@", obj);
        [weakSelf requestConfigSuccess:obj];
    }];
}

- (void)requestConfigSuccess:(NSDictionary *)obj {
    PTBCommonDataSource *commonDataSource = [PTBCommonDataSource sharedInstance];
    if (obj && [obj[@"code"] integerValue] == 200) {
        NSArray *travelManagement = obj[@"map"][@"TravelManagement"];
        if (travelManagement.count > 0) {
            commonDataSource.routeManagerItems = travelManagement;
            commonDataSource.isNewRouteManagerItems = YES;
            [kPPUserDefault setObject:travelManagement forKey:kLastRouteManagerItemsKey];
            [kPPUserDefault synchronize];
        }
    }
}

#pragma mark - 是否赠送保险
- (void)requestForGiveInsurer {
    PPWeakSelf;
    [PPHttpManager request:kGiveInsurer params:nil success:^(PPRequest *request, NSDictionary *obj) {
        //返回的DESC中Y和N代表是与否
        if (obj && [obj[@"code"] integerValue] == 200) {
            NSString *desc = obj[@"desc"];
            weakSelf.isGiveInsurer = [desc isEqualToString:@"Y"];
        }
    }];
}

#pragma mark - 移动端升级
- (void)requestForUpgrade {
    PPWeakSelf;
    NSDictionary *params = @{@"packages":kPTB_UpdatePackage,
                             @"channel":kPTB_UpdateChannel,
                             @"p":@"i"};
    [PPHttpManager request:kUpgrade params:params success:^(PPRequest *request, NSDictionary *obj) {
        if (obj && [obj[@"code"] integerValue] == 200) {
            DLog(@"newUpdate: %@", obj[@"object"]);
            [weakSelf analysisForUpdateDic:obj[@"object"]];
        }
    }];
}

#pragma mark - 获取当前字体
- (UIFont *)currentFontWithSize:(CGFloat)size {
    UIFont *resultFont = [UIFont systemFontOfSize:size];
    if (PPNonNullString(_currentFontName)) {
        UIFont* aFont = [UIFont fontWithName:_currentFontName size:size];
        if (aFont && ([aFont.fontName compare:_currentFontName] == NSOrderedSame || [aFont.familyName compare:_currentFontName] == NSOrderedSame)) {
            resultFont = aFont;
        }
    }
    return resultFont;
}

#pragma mark - 发版之前拉取最新基础数据
//- (void)writeFile:(id)file toPath:(NSString *)path {
//    DLog(@"path : %@", path);
//    [PPFileManager writeToJsonFile:file path:path complete:nil];
//}

#pragma mark - 获取自费邮寄行程单费用	
- (void)requestOrderPostage {
    [PPHttpManager request:kGetPostage params:nil showHud:NO success:^(PPRequest *request, NSDictionary *obj) {
        if ([obj[@"code"] integerValue] == 200) {
            PTBCommonDataSource * dataSource = [PTBCommonDataSource sharedInstance];
            dataSource.itineraryPostage = [[obj[@"desc"] pp_editStringOfPoint] floatValue];
        }
    } failure:^(PPRequest *request, NSError *error) {
        DLog(@"%@", error.description);
    }];
}

//处理点击3Dtouch打开app
-(void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler{
    [PTBCommonConfigure dealwith3DTouch:shortcutItem];
}



- (void)reGetOrderRemindTime{
    [kPPNoticeCenter postNotificationName:kRegetOrderCountDownTime object:nil];
}

@end

