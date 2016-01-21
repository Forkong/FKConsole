//
//  NSObject_Extension.m
//  FKConsole
//
//  Created by Fujun on 16/1/20.
//  Copyright © 2016年 Fujun. All rights reserved.
//


#import "NSObject_Extension.h"
#import "FKConsole.h"

@implementation NSObject (Xcode_Plugin_Template_Extension)

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[FKConsole alloc] initWithBundle:plugin];
        });
    }
}

@end
