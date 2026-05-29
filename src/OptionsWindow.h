// OptionsWindow.h — the "Analyse Plugin Options" dialog (port of ConfigDialog).
//
// Three groups matching IDD_ANALYSE_CONF_DLG / Image #2: Default Values,
// Behaviour, Result Window Font. Edits NSUserDefaults and, on OK, asks the
// controller to re-apply settings to the panels.

#import <Cocoa/Cocoa.h>

@class AnalyseController;

NS_ASSUME_NONNULL_BEGIN

// NSUserDefaults keys (defaults registered in AnalyseController).
extern NSString *const kAPDefSearchType;    // int 0..3
extern NSString *const kAPDefMatchCase;      // bool
extern NSString *const kAPDefWholeWord;      // bool
extern NSString *const kAPDefDoSearch;       // bool
extern NSString *const kAPDefHideText;       // bool
extern NSString *const kAPDefFgColor;        // int (COLORREF)
extern NSString *const kAPDefBgColor;        // int (COLORREF)
extern NSString *const kAPDefSelection;      // int 0=text,1=line
extern NSString *const kAPUseBookmark;       // bool
extern NSString *const kAPAutoUpdate;        // bool
extern NSString *const kAPSyncScroll;        // bool
extern NSString *const kAPDblClickJumps;     // bool
extern NSString *const kAPOnEnterAction;     // int 0=just search,1=update,2=add
extern NSString *const kAPNumCfgFiles;       // int
extern NSString *const kAPResultFontName;    // string
extern NSString *const kAPResultFontSize;    // int
extern NSString *const kAPShowLineNumbers;   // bool
extern NSString *const kAPWordWrap;          // bool

@interface OptionsWindow : NSWindowController

- (instancetype)initWithController:(AnalyseController *)controller;
- (void)showModal;

@end

NS_ASSUME_NONNULL_END
