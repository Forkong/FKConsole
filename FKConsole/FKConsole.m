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
@property (nonatomic, strong) IDEConsoleTextView *fkConsoleTextView;
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
    if (!self.fkConsoleTextView &&
        self.menuState == NSOnState)
    {
        [self installHook];
    }
}

#pragma mark -- delegate
- (void)textStorage:(NSTextStorage *)textStorage
 willProcessEditing:(NSTextStorageEditActions)editedMask
              range:(NSRange)editedRange
     changeInLength:(NSInteger)delta
{
    if (editedRange.length == 0)
    {
        return;
    }
    
    NSString *contentsMutableString = [textStorage valueForKeyPath:kContentMutableStringKey];
    NSString *editRangeString = [contentsMutableString substringWithRange:editedRange];
    //只处理需要修改的范围内的内容
    NSString *fixedRangeString = [self stringByReplaceUnicode:editRangeString];
    NSString *fixedMutableString = [contentsMutableString stringByReplacingCharactersInRange:editedRange withString:fixedRangeString];
    
    [textStorage setValue:fixedMutableString forKeyPath:kContentMutableStringKey];
    [textStorage setValue:[NSValue valueWithRange:NSMakeRange(editedRange.location, fixedMutableString.length-editedRange.location)] forKeyPath:@"_editedRange"];
    [textStorage setValue:@(fixedMutableString.length-editedRange.location) forKeyPath:@"_editedDelta"];
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
    
    [self updateHookWithState:subMenuItem.state];
}

- (void)updateHookWithState:(NSCellStateValue)state
{
    self.menuState = state;
    switch (state)
    {
        case NSOnState:
        {
            [self installHook];
        }
            break;
        case NSOffState:
        {
            [self unInstallHook];
        }
            break;
        default:
            break;
    }
}

- (void)toggleMenu:(NSMenuItem *)menuItem
{
    menuItem.state = !menuItem.state;
    
    [self updateHookWithState:menuItem.state];
    
    [[NSUserDefaults standardUserDefaults] setValue:@(menuItem.state) forKey:kFKConsoleStoreKey];
}

- (void)installHook
{
    [self findIDEConsoleTextViewWithView:[[NSApp mainWindow] contentView]];
    if (self.fkConsoleTextView)
    {
        self.fkConsoleTextView.textStorage.delegate = self;
    }
}
- (void)unInstallHook
{
    if (self.fkConsoleTextView)
    {
        self.fkConsoleTextView.textStorage.delegate = nil;
    }
}

- (void)findIDEConsoleTextViewWithView:(NSView *)subView
{
    if (subView.subviews.count == 0)
    {
        return;
    }
    
    for (NSView *tempView in subView.subviews)
    {
        if ([self isKindOfIDEConsoleTextView:tempView])
        {
            self.fkConsoleTextView = (IDEConsoleTextView *)tempView;
            break;
        }
        else
        {
            [self findIDEConsoleTextViewWithView:tempView];
        }
    }
}

- (BOOL)isKindOfIDEConsoleTextView:(NSView *)subView
{
    if ([subView isKindOfClass:NSClassFromString(@"IDEConsoleTextView")])
    {
        return YES;
    }
    return NO;
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
