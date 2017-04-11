//
//  UncaughtExceptionHandler.m
//  qmp_ios_v2.0
//
//  Created by Molly on 2017/2/6.
//  Copyright © 2017年 Molly. All rights reserved.
//

#import "UncaughtExceptionHandler.h"
#import <UIKit/UIKit.h>
#include <libkern/OSAtomic.h>
#include <execinfo.h>

#import "JKEncrypt.h"
#import "UploadItem.h"
#import "RequestUrlItem.h"
#import "GetNowTime.h"
#import "NetworkingManager.h"

NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString * const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
NSString * const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";
volatile int32_t UncaughtExceptionCount = 0;
const int32_t UncaughtExceptionMaximum = 10;
const NSInteger UncaughtExceptionHandlerSkipAddressCount = 4;
const NSInteger UncaughtExceptionHandlerReportAddressCount = 5;
static BOOL hasCatchE = NO;
NSString* getAppInfo()
{
    NSString *name = [[NSUserDefaults standardUserDefaults] objectForKey:@"nickname"];
    
    NSString *appInfo = [NSString stringWithFormat:@"App : %@ %@(%@)\nDevice : %@\niOS Version : %@ %@\n ",
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"],
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                         [UIDevice currentDevice].model,
                         [UIDevice currentDevice].systemName,
                         [UIDevice currentDevice].systemVersion];
    //   NSString *ip = toGetPublicIP();
    NSString *info = [NSString stringWithFormat:@"%@ \n name: %@" ,appInfo,name ? name : @""];
    
    return info;
}


void sendEmailWithDesc(NSString * exceptionStr,NSString *name,NSString *urlStr){
    
    // 创建异常log
    GetNowTime *timeTool = [[GetNowTime alloc] init];
    
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *filename = [NSString stringWithFormat:@"error%@.txt",[timeTool getDayWithHour]];;
    NSString *dirPath = [cachePath stringByAppendingPathComponent:filename];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:dirPath]) {
        [fileManager removeItemAtPath:dirPath error:nil];
    }
    NSData *data = [exceptionStr dataUsingEncoding:NSUTF8StringEncoding];
    // 字符串写入时执行的方法
    BOOL isWrite = [fileManager createFileAtPath:dirPath contents:data attributes:nil];
    
    if (isWrite) {
        //将错误日志上传上去
        NSString *unionid = [[NSUserDefaults standardUserDefaults] objectForKey:@"unionid"];
        RequestUrlItem *request = [[RequestUrlItem alloc] initWithParamsDic:@{} onPlist:@"" onAction:@""];
        UploadItem *item = [[UploadItem alloc] init];
        item.fileName = filename;
        item.filePath = dirPath;
        
        NetworkingManager *manager = [[NetworkingManager alloc] init];
        [manager asyncPostUploadTaskWithRequestUrlItem:request withUploadModel:item withSuccessCallBack:^(NSDictionary *resultDic) {
            NSLog(@"success==================log");
            
            //将收集到的崩溃日志进行处理，上报服务器或者提示用户邮件发送等等。。。
            
            NSURL *url = [NSURL URLWithString:[[urlStr stringByAppendingString:@"<br>post success! <br>"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            [[UIApplication sharedApplication] openURL:url];
            
        } andFaildCallBack:^(id response) {
            //将收集到的崩溃日志进行处理，上报服务器或者提示用户邮件发送等等。。。
            NSURL *url = [NSURL URLWithString:[[urlStr stringByAppendingString:@"<br>post fail! <br>"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            [[UIApplication sharedApplication] openURL:url];
            
        }];
    }
}

void MySignalHandler(int signal)
{
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount > UncaughtExceptionMaximum)
    {
        return;
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    
    NSMutableString *mstr = [[NSMutableString alloc] init];
    [mstr appendString:@"Stack:\n"];
    void* callstack[128];
    int i, frames = backtrace(callstack, 128);
    char** strs = backtrace_symbols(callstack, frames);
    for (i = 0; i <frames; ++i) {
        [mstr appendFormat:@"%s\n", strs[i]];
    }
    
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *name = [NSString stringWithFormat:@"signal%d",signal];
    NSString *urlStr = [NSString stringWithFormat:@"mailto://molly@qimingpian.com?subject=%@错误报告&body=%@发生错误啦,感谢您的反馈! <br><br><br>"
                        "错误详情:<br>%@<br>--------------------------<br>%@<br>--------------------------<br>%@",appName,appName,
                        name,[callStack componentsJoinedByString:@"<br>"],getAppInfo()];
    
    if (!hasCatchE) {
        sendEmailWithDesc(mstr, name, urlStr);
        
    }
    
    NSException *exception = [NSException
                              exceptionWithName:UncaughtExceptionHandlerSignalExceptionName
                              reason:
                              [NSString stringWithFormat:
                               NSLocalizedString(@"Signal %d 发生\n %@"
                                                 @"%@", nil),
                               signal, mstr,getAppInfo()]
                              userInfo:
                              [NSDictionary
                               dictionaryWithObject:[NSNumber numberWithInt:signal]
                               forKey:UncaughtExceptionHandlerSignalKey] ];
    [[[UncaughtExceptionHandler alloc] init]
     performSelectorOnMainThread:@selector(handleException:)
     withObject:exception
     waitUntilDone:YES];
    
}


@implementation UncaughtExceptionHandler
+(void) InstallUncaughtExceptionHandler
{
    signal(SIGABRT, MySignalHandler);//异常终止条件，例如abort()所发动者
    signal(SIGILL, MySignalHandler);//非法程序映像，例如非法指令
    signal(SIGSEGV, MySignalHandler);//非法内存访问（段错误）
    signal(SIGFPE, MySignalHandler);//错误的算术运算，例如除以零
    signal(SIGBUS, MySignalHandler);//程序内存字节未对齐中止信号
    signal(SIGPIPE, MySignalHandler);//程序Socket发送失败中止信号
    
    signal(SIGHUP, MySignalHandler);
    signal(SIGINT, MySignalHandler);
    signal(SIGQUIT, MySignalHandler);
}

+ (NSArray *)backtrace
{
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (
         i = UncaughtExceptionHandlerSkipAddressCount;
         i < UncaughtExceptionHandlerSkipAddressCount +
         UncaughtExceptionHandlerReportAddressCount;
         i++)
    {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    return backtrace;
}

- (void)handleException:(NSException *)exception
{
    
    NSString *address = [[exception userInfo] objectForKey:UncaughtExceptionHandlerAddressesKey];
    UIAlertView *alert =
    
    [[UIAlertView alloc]
     initWithTitle:@"未经处理的异常"
     message:[NSString stringWithFormat:@"APP出现问题,暂时无法使用!\n%@\n%@您可以直接通过微信或者打电话联系我们!CEO微信/手机: 13381063557",
              [exception reason],
              address ? address : @""]
     delegate:self
     cancelButtonTitle:@"好的"
     otherButtonTitles:nil, nil];
    [alert show];
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    while (alert.visible)
    {
        for (NSString *mode in (__bridge NSArray *)allModes)
        {
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    CFRelease(allModes);
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName])
    {
        kill(getpid(), [[[exception userInfo] objectForKey:UncaughtExceptionHandlerSignalKey] intValue]);
    }
    else
    {
        [exception raise];
    }
}
void UncaughtExceptionHandlers (NSException *exception) {
    
    hasCatchE = YES;
    uploadExceptionLogAndSendEmail(exception);
}

void uploadExceptionLogAndSendEmail(NSException *exception){
    //下面代码可以获取到崩溃异常的相关信息
    NSString *APPinfoNotEn = getAppInfo();
    NSString *APPinfoEn = getAppInfo();
    
    //如果用户登录了将其unionid(3des加密过后的)传过去  molly 170206--
    NSString *unionid = [[NSUserDefaults standardUserDefaults] objectForKey:@"unionid"];
    if (unionid && ![unionid isEqualToString:@""]) {
        JKEncrypt *enTool = [[JKEncrypt alloc] init];
        APPinfoEn = [NSString stringWithFormat:@"%@\nuser : %@",APPinfoEn,[enTool doEncryptStr:unionid]];
        APPinfoNotEn = [NSString stringWithFormat:@"%@\nuser : %@",APPinfoEn,[enTool doEncryptStr:unionid]];
    }
    //-- 如果用户登录了将其unionid(3des加密过后的)传过去 molly 170206
    
    
    NSArray *callStack = [exception callStackSymbols];
    NSString *reason = [exception reason];
    NSString *name = [exception name];
    
    
    NSString *exceptionStr = [NSString stringWithFormat:@"%@\n--------------------------\n%@\n--------------------------\n%@\n--------------------------\n%@",name,reason,[callStack componentsJoinedByString:@"\n"],APPinfoNotEn];
    
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *urlStr = [NSString stringWithFormat:@"mailto://molly@qimingpian.com?subject=%@错误报告&body=%@发生错误啦,您可以直接通过微信或者打电话联系我们!CEO微信/手机: 13381063557 ! 或者发送此邮件,感谢您的反馈!Crash <br><br><br>"
                        "错误详情:<br>%@<br>--------------------------<br>%@<br>--------------------------<br>%@<br>--------------------------<br><br>%@ <br>",appName,appName,
                        name,reason,[callStack componentsJoinedByString:@"<br>"],APPinfoEn];
    
    sendEmailWithDesc(exceptionStr, name, urlStr);
    //或者直接用代码，输入这个崩溃信息，以便在console中进一步分析错误原因
    NSLog(@"===================, CRASH: %@", exception);
    NSLog(@"==========info%@", APPinfoNotEn);
    NSLog(@"==============, Stack Trace: %@", [exception callStackSymbols]);
    NSLog(@"===log===");
}


@end
