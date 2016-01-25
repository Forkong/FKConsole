//
//  FKConsole.m
//  FKConsole
//
//  Created by Fujun on 16/1/20.
//  Copyright © 2016年 Fujun. All rights reserved.
//

#import "FKConsole.h"
#import "IDEConsoleTextView.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>

static NSString * const kFKConsoleStoreKey = @"FKConsole";

static NSString * const kContentMutableStringKey = @"_contents.mutableString";

static NSString * const kStartLocationOfLastLineKey = @"_startLocationOfLastLine";

static NSString * const kLastRemovableTextLocationKey = @"_lastRemovableTextLocation";

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
        [self addMethod];
        
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
- (void)addMethod
{
    [self addMethodWithNewMethod:@selector(fk_checkTextView:)
                    originMethod:nil];

    [self addMethodWithNewMethod:@selector(fk_insertText:)
                    originMethod:@selector(insertText:)];
    
    [self addMethodWithNewMethod:@selector(fk_insertNewline:)
                    originMethod:@selector(insertNewline:)];
    
    [self addMethodWithNewMethod:@selector(fk_clearConsoleItems)
                    originMethod:@selector(clearConsoleItems)];
    
    [self addMethodWithNewMethod:@selector(fk_shouldChangeTextInRanges:replacementStrings:)
                    originMethod:@selector(shouldChangeTextInRanges:replacementStrings:)];
}

- (void)addMethodWithNewMethod:(SEL)newMethod originMethod:(SEL)originMethod
{
    Method targetMethod = class_getInstanceMethod(NSClassFromString(@"IDEConsoleTextView"), newMethod);
    
    Method consoleMethod = class_getInstanceMethod(self.class, newMethod);
    IMP consoleIMP = method_getImplementation(consoleMethod);
    
    if (!targetMethod)
    {
        class_addMethod(NSClassFromString(@"IDEConsoleTextView"), newMethod, consoleIMP, method_getTypeEncoding(consoleMethod));
        
        if (originMethod)
        {
            NSError *error;
            [NSClassFromString(@"IDEConsoleTextView")
             jr_swizzleMethod:newMethod
             withMethod:originMethod
             error:&error];
            NSLog(@"error = %@", error);
        }
    }
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
        editedMask == NSTextStorageEditedAttributes ||
        editedRange.length <= 0)
    {
        return;
    }
    
    NSString *contentsMutableString =
    editedRange.location == 0?
    [[textStorage valueForKeyPath:kContentMutableStringKey]
     substringWithRange:[[textStorage valueForKeyPath:kContentMutableStringKey] rangeOfComposedCharacterSequencesForRange:editedRange]]:
    [textStorage valueForKeyPath:kContentMutableStringKey];
    
    if (contentsMutableString.length < (editedRange.location + editedRange.length))
    {
        return;
    }
    
    NSString *editRangeString =
    [contentsMutableString substringWithRange:
     [contentsMutableString rangeOfComposedCharacterSequencesForRange:editedRange]];
    
    //只处理需要修改的范围内的内容
    NSString *fixedRangeString = [self stringByReplaceUnicode:editRangeString];
    
//    NSLog(@"--\n%ld -- %ld -- %ld",editedRange.location, editedRange.length, fixedRangeString.length);
    [textStorage beginEditing];
    [textStorage replaceCharactersInRange:editedRange withString:fixedRangeString];
    [textStorage endEditing];    
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
    //from http://stackoverflow.com/questions/13240620/uilabel-text-with-unicode-nsstring
    NSMutableString *convertedString = [string mutableCopy];
    [convertedString replaceOccurrencesOfString:@"\\U"
                                     withString:@"\\u"
                                        options:0
                                          range:NSMakeRange(0, convertedString.length)];
    CFStringRef transform = CFSTR("Any-Hex/Java");
    CFStringTransform((__bridge CFMutableStringRef)convertedString, NULL, transform, YES);
    return convertedString;
}

#pragma mark - method swizzle
- (void)fk_checkTextView:(IDEConsoleTextView *)textView
{
    if (textView.textStorage.length < [[textView valueForKeyPath:kStartLocationOfLastLineKey] longLongValue])
    {
        [textView setValue:@(textView.textStorage.length) forKeyPath:kStartLocationOfLastLineKey];
    }
    if (textView.textStorage.length < [[textView valueForKeyPath:kLastRemovableTextLocationKey] longLongValue])
    {
        [textView setValue:@(textView.textStorage.length) forKeyPath:kLastRemovableTextLocationKey];
    }
}
- (void)fk_insertText:(id)arg1
{
    [self fk_checkTextView:(IDEConsoleTextView *)self];
    [self fk_insertText:arg1];
}
- (void)fk_insertNewline:(id)arg1
{
    [self fk_checkTextView:(IDEConsoleTextView *)self];
    [self fk_insertNewline:arg1];
}
- (void)fk_clearConsoleItems
{
    [self fk_checkTextView:(IDEConsoleTextView *)self];
    [self fk_clearConsoleItems];
}
- (BOOL)fk_shouldChangeTextInRanges:(id)arg1 replacementStrings:(id)arg2
{
    [self fk_checkTextView:(IDEConsoleTextView *)self];
    return [self fk_shouldChangeTextInRanges:arg1 replacementStrings:arg2];
}
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
