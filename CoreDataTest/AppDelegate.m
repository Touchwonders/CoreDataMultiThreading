//
//  AppDelegate.m
//  CoreDataTest
//
//  Created by Robin van Dijke on 25-06-12.
//  Copyright (c) 2012 Touchwonders B.V. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "AppDelegate.h"
#import "CoreDataTest.h"

@implementation AppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // initialize test
    CoreDataTest *coreDataTest = [[CoreDataTest alloc] init];
    [coreDataTest coreDataTest];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
