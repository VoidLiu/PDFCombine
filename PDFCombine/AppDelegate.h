//
//  AppDelegate.h
//  PDFCombine
//
//  Created by Tom on 01/12/13.
//  Copyright (c) 2013 Tom Works. All rights reserved.
//

#import <Cocoa/Cocoa.h>
extern NSString *const PROCESSING_MESSAGE;
extern NSString *const INVALID_DIRECTORY_MESSAGE;
extern NSString *const PROCESSING_COMPLETE_MESSAGE;
extern NSString *const SET_DIRECTORY_MESSAGE;
extern NSString *const DOUBLE_CLICK_MESSAGE;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSPathControlDelegate>

@end
