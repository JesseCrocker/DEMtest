//
//  AppDelegate.h
//  DEM viewer
//
//  Created by Jesse Crocker on 8/8/12.
//  Copyright (c) 2012 Jesse Crocker. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

- (NSString *)applicationDocumentsDirectory ;

@end
