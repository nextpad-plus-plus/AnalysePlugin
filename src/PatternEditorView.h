// PatternEditorView.h — the "Analyse Plugin" docked pattern-list editor panel.
//
// macOS port of the Windows FindDlg. Owns the tclResultList (patterns + their
// results). The full edit controls + 13-column table land in a later UI pass;
// this header already exposes the model + the two menu commands so the search
// pipeline works end-to-end.

#import <Cocoa/Cocoa.h>

#include "tclResultList.h"

@class AnalyseController;

NS_ASSUME_NONNULL_BEGIN

@interface PatternEditorView : NSView

- (instancetype)initWithController:(AnalyseController *)controller;

// The pattern+result model the engine searches over.
- (tclResultList &)resultListRef;

- (void)addSelectionAsPatterns;
- (void)runSearch;

// Default pattern used for new rows / as the result default style.
- (const tclPattern &)defaultPattern;

@end

NS_ASSUME_NONNULL_END
