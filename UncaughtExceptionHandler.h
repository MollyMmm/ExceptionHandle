//
//  UncaughtExceptionHandler.h
//  qmp_ios_v2.0
//
//  Created by Molly on 2017/2/6.
//  Copyright © 2017年 Molly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UncaughtExceptionHandler : NSObject
{
    BOOL dismissed;
}
+ (NSArray *)backtrace;
+(void) InstallUncaughtExceptionHandler;
void UncaughtExceptionHandlers (NSException *exception);
@end
