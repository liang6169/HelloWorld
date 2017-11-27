//
//  PTBAppDelegate.h
//  Biqu
//
//  Created by 闫鹏 on 15/7/13.
//  Copyright (c) 2015年 Taifu Aviation Service Co., Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WXApi.h"
#import "PTBUserInfo.h"

const static NSString *CREDITBANKS  = @"creditBanks";   // 信用卡key
const static NSString *SAVINGBANKS  = @"savingBanks";   // 储蓄卡key
const static NSString *CREDTYPES    = @"credTypes";     // 证件类型key
const static NSString *CURRENTDATE  = @"currentDate";   // 当前日期

@class YYDiskCache;
@interface PTBAppDelegate : UIResponder <UIApplicationDelegate,WXApiDelegate>

@property (nonatomic,   copy) NSString * pushToken;
@property (nonatomic,   copy) NSString * firstTm;
@property (nonatomic,   copy) NSString * currentFontName;
@property (nonatomic,   copy) NSString * currentCity;
@property (nonatomic,   copy) NSString * sessionid;

@property (nonatomic, assign) BOOL isNeedLogin;
@property (nonatomic, assign) BOOL isNotNeedRequest;
@property (nonatomic, assign) BOOL isLanchByRemoteNotif;
@property (nonatomic, assign) BOOL isGiveInsurer;

@property (nonatomic, strong) UIWindow * window;
@property (nonatomic, strong) PTBUserInfo * userInfo;
@property (nonatomic, strong) YYDiskCache *diskCache;


- (UIFont *)currentFontWithSize:(CGFloat)size;  //获取当前使用的字体

@end

