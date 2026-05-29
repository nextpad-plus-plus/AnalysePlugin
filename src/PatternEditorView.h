// PatternEditorView.h — the "Analyse Plugin" docked pattern-list editor panel.
//
// (Phase-4 placeholder: full pattern table + edit controls + buttons land next.)

#import <Cocoa/Cocoa.h>

@class AnalyseController;

NS_ASSUME_NONNULL_BEGIN

@interface PatternEditorView : NSView

- (instancetype)initWithController:(AnalyseController *)controller;

- (void)addSelectionAsPatterns;
- (void)runSearch;

@end

NS_ASSUME_NONNULL_END
