// HelpWindow.h — the "Analyse Plugin Help" dialog (port of HelpDialog).
//
// Shows version / author / email / homepage and a monospaced, scrollable text
// area that toggles between the Manual (manual.txt) and Changes (changes.txt),
// which are installed next to the plugin dylib and located at runtime.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface HelpWindow : NSWindowController

- (instancetype)init;
- (void)showHelp;

@end

NS_ASSUME_NONNULL_END
