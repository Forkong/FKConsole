//
//  FKConsole.m
//  FKConsole
//
//  Created by Fujun on 16/1/20.
//  Copyright © 2016年 Fujun. All rights reserved.
//

#import "FKConsole.h"
#import "IDEConsoleTextView.h"

static NSString * const kFKConsoleStoreKey = @"FKConsole";

static NSString * const kContentMutableStringKey = @"_contents.mutableString";

@interface FKConsole()<NSTextStorageDelegate>

@property (nonatomic, strong, readwrite) NSBundle *bundle;

@property (nonatomic, assign) NSCellStateValue menuState;
@end

@implementation FKConsole
#pragma mark -- life circle
+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init])
    {
        self.bundle = plugin;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didApplicationFinishLaunchingNotification:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(textStorageDidChange:)
                                                     name:NSTextDidChangeNotification
                                                   object:nil];
        
    }
    return self;
}

#pragma mark -- notification
- (void)didApplicationFinishLaunchingNotification:(NSNotification*)noti
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSApplicationDidFinishLaunchingNotification
                                                  object:nil];
    
    [self addMenu];
}

- (void)textStorageDidChange:(NSNotification *)noti
{
    if ([noti.object isKindOfClass:NSClassFromString(@"IDEConsoleTextView")] &&
        ((IDEConsoleTextView *)noti.object).textStorage.delegate != self)
    {
        ((IDEConsoleTextView *)noti.object).textStorage.delegate = self;
    }
}

#pragma mark -- delegate
- (void)textStorage:(NSTextStorage *)textStorage
 willProcessEditing:(NSTextStorageEditActions)editedMask
              range:(NSRange)editedRange
     changeInLength:(NSInteger)delta
{
    if (self.menuState == NSOffState ||
        editedRange.length == 0)
    {
        return;
    }
    
    NSString *contentsMutableString =
    editedRange.location == 0?
    [[textStorage valueForKeyPath:kContentMutableStringKey] substringWithRange:editedRange]:
    [textStorage valueForKeyPath:kContentMutableStringKey];
    
    if (contentsMutableString.length < editedRange.location)
    {
        return;
    }
    
    NSString *editRangeString = [contentsMutableString substringWithRange:editedRange];
    //只处理需要修改的范围内的内容
    NSString *fixedRangeString = [self stringByReplaceUnicode:editRangeString];
    NSString *fixedMutableString = [contentsMutableString stringByReplacingCharactersInRange:editedRange
                                                                                  withString:fixedRangeString];
    
//    NSLog(@"--\n%ld -- %ld -- %ld",editedRange.location, editedRange.length, fixedMutableString.length);

    [textStorage setValue:fixedMutableString
               forKeyPath:kContentMutableStringKey];
    
    [textStorage setValue:[NSValue valueWithRange:NSMakeRange(editedRange.location,
                                                              fixedMutableString.length-editedRange.location)]
               forKeyPath:@"_editedRange"];
    
    [textStorage setValue:@(fixedMutableString.length-editedRange.location)
               forKeyPath:@"_editedDelta"];
}
#pragma mark -- mathod
- (void)addMenu
{
    NSMenu *mainMenu = [NSApp mainMenu];
    if (!mainMenu)
    {
        return;
    }

    NSMenuItem *pluginsMenuItem = [mainMenu itemWithTitle:@"Plugins"];
    if (!pluginsMenuItem)
    {
        pluginsMenuItem = [[NSMenuItem alloc] init];
        pluginsMenuItem.title = @"Plugins";
        pluginsMenuItem.submenu = [[NSMenu alloc] initWithTitle:pluginsMenuItem.title];
        NSInteger windowIndex = [mainMenu indexOfItemWithTitle:@"Window"];
        [mainMenu insertItem:pluginsMenuItem atIndex:windowIndex];
    }
    
    NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:kFKConsoleStoreKey];
    if (!value)
    {
        value = @(1);
    }
    
    NSMenuItem *subMenuItem = [[NSMenuItem alloc] init];
    subMenuItem.title = @"FKConsole";
    subMenuItem.target = self;
    subMenuItem.action = @selector(toggleMenu:);
    subMenuItem.state = value.boolValue?NSOnState:NSOffState;
    [pluginsMenuItem.submenu addItem:subMenuItem];
    
    self.menuState = subMenuItem.state;
}

- (void)toggleMenu:(NSMenuItem *)menuItem
{
    menuItem.state = !menuItem.state;
    
    self.menuState = menuItem.state;
    
    [[NSUserDefaults standardUserDefaults] setValue:@(menuItem.state) forKey:kFKConsoleStoreKey];
}

- (NSString *)stringByReplaceUnicode:(NSString *)string
{
    //来自 http://stackoverflow.com/questions/13240620/uilabel-text-with-unicode-nsstring
    NSMutableString *convertedString = [string mutableCopy];
    [convertedString replaceOccurrencesOfString:@"\\U" withString:@"\\u" options:0 range:NSMakeRange(0, convertedString.length)];
    CFStringRef transform = CFSTR("Any-Hex/Java");
    CFStringTransform((__bridge CFMutableStringRef)convertedString, NULL, transform, YES);
    return convertedString;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
