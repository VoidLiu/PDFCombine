//
//  AppDelegate.m
//  PDFCombine
//
//  Created by Tom on 01/12/13.
//  Copyright (c) 2013 Tom Works. All rights reserved.
//

#import "AppDelegate.h"
#import <Quartz/Quartz.h>

NSString *const PROCESSING_MESSAGE = @"Output PDF is in the making............ Please Wait........";
NSString *const INVALID_DIRECTORY_MESSAGE = @"Check your input directory, it might not have the right kind of files and/or PDF file names";
NSString *const PROCESSING_COMPLETE_MESSAGE = @"The output file is created";
NSString *const SET_DIRECTORY_MESSAGE = @"Set the input directory. This is done by either setting the item path or by dragging and dropping the path";
NSString *const DOUBLE_CLICK_MESSAGE = @"Double-click a path component to reveal it in the Finder.";

@interface AppDelegate()
@property (weak) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSPathControl *pathControl;
@property (weak) IBOutlet NSTextField *explanationText;
@property (weak) IBOutlet NSButton *pathSetButton;
@property (weak) IBOutlet NSButton *combineButton;
@property (assign, readonly) BOOL hasValidPDFFolderPath;
@property (strong) NSArray *sortedPDFFileNameArray;
@property (strong) NSString *currentFolderPath;
@property (assign) BOOL isProcessing;

- (void)updateCombineButton;
- (void)updateExplainText:(NSString *)text;
@end

@implementation AppDelegate

- (void)awakeFromNib
{
    /*
     Configure the double action for the path control. (There's no need to set the target because it's already set for the single-click action in the nib file.)
     */
    [self.pathControl setDoubleAction:@selector(pathControlDoubleClick:)];
    
    // Clear the explanation text.
    [self.explanationText setStringValue:SET_DIRECTORY_MESSAGE];
    _sortedPDFFileNameArray = nil;
    _currentFolderPath = nil;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //disable the combine button at launch
    [_combineButton setEnabled:NO];
}

- (BOOL)hasValidPDFFolderPath{

    NSURL* fileURL;
    NSURL *url = [[self.pathControl URL] filePathURL] ;
    _currentFolderPath = [url path];
    NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager] enumeratorAtURL:url includingPropertiesForKeys:[NSArray arrayWithObject:NSURLNameKey] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    
    NSNumberFormatter *integerNumberFormatter = [[NSNumberFormatter alloc] init];
    [integerNumberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [integerNumberFormatter setMaximumFractionDigits:0];
    
    //the pdf files are expected to be named in a sequence with string as the filename
    //say if there are 100 files, the first pdf will be named as 001 and the 100th filename will be 100
    NSMutableArray *pdfFileNameArray = [NSMutableArray array];
    
    while (fileURL = [enumerator nextObject])
    {
        // check if it's a directory
        BOOL isDirectory = NO;
        NSString *filePath = [[fileURL filePathURL] path];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath
                                             isDirectory: &isDirectory];
        if (!fileExists) {
            return NO;
        }
        
        if (!isDirectory)
        {
            //if number is non-nil, it indicates that the pdf file was named using a valid number string
            NSNumber *number = [integerNumberFormatter numberFromString:[[filePath lastPathComponent] stringByDeletingPathExtension]];
            CFStringRef fileExtension = (__bridge CFStringRef) [filePath pathExtension];
            CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
            
            //check whether the pdf file is named appropriate
            if ((number == nil) || !UTTypeConformsTo(fileUTI, kUTTypePDF)) {
                return NO;
            }
            [pdfFileNameArray addObject:[[filePath lastPathComponent] stringByDeletingPathExtension]];
        }
    }
    
    _sortedPDFFileNameArray = [pdfFileNameArray sortedArrayUsingDescriptors:
                        @[[NSSortDescriptor sortDescriptorWithKey:@"integerValue"
                                                        ascending:YES]]];
    return YES;
    
}

- (IBAction)combine:(id)sender {
    PDFDocument *outputDocument = [[PDFDocument alloc] init];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    [queue addOperationWithBlock:^{
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            _isProcessing = YES;
            [self updateCombineButton];
            [self updateExplainText:PROCESSING_MESSAGE];
        }];
        NSUInteger pageIndex = 0;
        for(NSString *fileName in _sortedPDFFileNameArray){
            //Create PDF document
            NSString *pdfFilePath = [NSString stringWithFormat:@"%@/%@.%@",_currentFolderPath, fileName, @"pdf"];
            PDFDocument *inputDocument = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:pdfFilePath]];
            for (NSUInteger j = 0; j < [inputDocument pageCount]; j++) {
                PDFPage *page = [inputDocument pageAtIndex:j];
                [outputDocument insertPage:page atIndex:pageIndex++];
            }
        }
        
        [outputDocument writeToURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@.pdf",_currentFolderPath,[_currentFolderPath lastPathComponent]]]];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            _isProcessing = NO;
            [self updateCombineButton];
            [self updateExplainText:PROCESSING_COMPLETE_MESSAGE];
        }];
    }];
    
}

#pragma mark - User Interaction

- (IBAction)showPathOpenPanel:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setResolvesAliases:YES];
    
    NSString *panelTitle = NSLocalizedString(@"Choose a Folder", @"Title for the open panel");
    [panel setTitle:panelTitle];
    
    NSString *promptString = NSLocalizedString(@"Choose", @"Prompt for the open panel prompt");
    [panel setPrompt:promptString];
    
    AppDelegate * __weak weakSelf = self;
    
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        
        // Hide the open panel.
        [panel orderOut:self];
        
        // If the return code wasn't OK, don't do anything.
        if (result != NSOKButton) {
            return;
        }
        // Get the first URL returned from the Open Panel and set it at the first path component of the control.
        NSURL *url = [[panel URLs] objectAtIndex:0];
        [weakSelf.pathControl setURL:url];
        if (![weakSelf hasValidPDFFolderPath]){
            [weakSelf updateExplainText:INVALID_DIRECTORY_MESSAGE];
        } else {
            // Update the explanation text to show the user how they can reveal the path component.
            [weakSelf updateExplainText:DOUBLE_CLICK_MESSAGE];
        }
        
        [self updateCombineButton];
    }];
}


#pragma mark - Drag and drop
/*
 This method updates the explanation string that instructs the user how they can reveal the path component.
 */
- (void)updateExplainText:(NSString *)text
{
    NSUInteger numItems = [[self.pathControl pathComponentCells] count];
    
    
    // If there are no path components, there is no explanatory text.
    if (numItems == 0) {
        [self.explanationText setStringValue:NSLocalizedString(SET_DIRECTORY_MESSAGE, @"")];
        return;
    } else {
        [self.explanationText setStringValue:NSLocalizedString(text, @"")];
    }
    
}


/*
 This method is called when an item is dragged over the control. Return NSDragOperationNone to refuse the drop, or anything else to accept it.
 */
- (NSDragOperation)pathControl:(NSPathControl *)pathControl validateDrop:(id <NSDraggingInfo>)info
{
    return NSDragOperationCopy;
}


/*
 Implement this method to accept the dropped contents previously accepted from validateDrop:.  Get the new URL from the pasteboard and set it to the path control.
 */
-(BOOL)pathControl:(NSPathControl *)pathControl acceptDrop:(id <NSDraggingInfo>)info
{
    BOOL result = NO;
    
    NSURL *URL = [NSURL URLFromPasteboard:[info draggingPasteboard]];
    if (URL != nil)
    {
        [self.pathControl setURL:URL];
        
        // If appropriate, tell the user how they can reveal the path component.
        [self updateExplainText:DOUBLE_CLICK_MESSAGE];
        [self updateCombineButton];
        result = YES;
    }
    
    return result;
}


/*
 This method is called when a drag is about to begin. It shows how to customize dragging by preventing "volumes" from being dragged.
 */
- (BOOL)pathControl:(NSPathControl *)pathControl shouldDragPathComponentCell:(NSPathComponentCell *)pathComponentCell withPasteboard:(NSPasteboard *)pasteboard
{
    BOOL result = YES;
    NSURL *URL = [pathComponentCell URL];
    
    if ([URL isFileURL])
    {
        NSArray* pathPieces = [[URL path] pathComponents];
        if ([pathPieces count] < 4) {
            result = NO;	// Don't allow dragging volumes.
        }
    }
    
    return result;
}


- (IBAction)pathControlSingleClick:(id)sender
{
    // Select that chosen component of the path.
	[self.pathControl setURL:[[self.pathControl clickedPathComponentCell] URL]];
}


/*
 This method is the "double-click" action for the control. Because we are using a standard style or navigation style control we ask for the  path component that was clicked.
 */
- (void)pathControlDoubleClick:(id)sender
{
    if ([self.pathControl clickedPathComponentCell] != nil) {
        
        [[NSWorkspace sharedWorkspace] openURL:[self.pathControl URL]];
    }
}

/*
 The action method from the custom menu item, "Reveal in Finder". Because we are a popup, we ask for the control's URL (not one of the path components).
 */
- (void)menuItemAction:(id)sender
{
    NSURL *URL = [[self.pathControl clickedPathComponentCell] URL];
    NSArray *URLArray = [NSArray arrayWithObject:URL];
    [[NSWorkspace sharedWorkspace] openURLs:URLArray withAppBundleIdentifier:@"com.apple.Finder" options:NSWorkspaceLaunchWithoutActivation additionalEventParamDescriptor:nil launchIdentifiers:NULL];
}

- (void)updateCombineButton{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL enable = [self hasValidPDFFolderPath] && !_isProcessing;
        [_combineButton setEnabled:enable];
    });
}
@end
