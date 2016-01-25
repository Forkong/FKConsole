//
//  FKConsole.h
//  FKConsole
//
//  Created by Fujun on 16/1/20.
//  Copyright © 2016年 Fujun. All rights reserved.
//

#import <AppKit/AppKit.h>

@class FKConsole;

static FKConsole *sharedPlugin;

@interface FKConsole : NSObject

+ (instancetype)sharedPlugin;
- (id)initWithBundle:(NSBundle *)plugin;

@property (nonatomic, strong, readonly) NSBundle* bundle;

@end