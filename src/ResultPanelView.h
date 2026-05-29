// ResultPanelView.h — the "Analyse Result" docked panel.
//
// macOS port of the Windows `tclFindResultDlg`: an NSView embedding a real
// Scintilla editor (the host's ScintillaView, resolved at runtime) that renders
// search results with per-pattern container styling, line-number prefixes,
// double-click-to-jump and scroll-sync — exactly like the Windows result window.

#import <Cocoa/Cocoa.h>

#include "tclPattern.h"
#include "tclPatternList.h"
#include "tclResult.h"
#include "tclFindResultDoc.h"

@class AnalyseController;

NS_ASSUME_NONNULL_BEGIN

@interface ResultPanelView : NSView

- (instancetype)initWithController:(AnalyseController *)controller;

// Raw message to the embedded result editor.
- (intptr_t)sci:(uint32_t)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam;

// ── Engine-facing API (ports of the tclFindResultDlg methods doSearch drives) ─
- (void)setPatternStyles:(const tclPatternList &)list
          defaultPattern:(const tclPattern &)defPat;
- (void)setLineText:(tiLine)foundLine
               text:(const std::string &)text
            comment:(const std::string &)comment
       commentWidth:(unsigned)commentWidth;
- (tiLine)insertPosInfo:(tPatId)patternId line:(tiLine)foundLine pos:(tclPosInfo)pos;
- (void)removeUnusedResultLines:(tPatId)pattId
                            old:(const tclResult &)oldResult
                            new:(const tclResult &)newResult;
- (BOOL)lineAvail:(tiLine)foundLine;
- (void)reserveLines:(unsigned)count;
- (void)clearResults:(BOOL)initial;
- (tiLine)resultSize;
- (int)lineNumColSize;
- (void)setLineNumColSize:(int)size;
- (void)setSearchFileName:(NSString *)name;
- (void)updateAfterSearch;            // line-number margin width + redraw

// Mirror the main editor's vertical scroll into the result (called by controller
// on the main editor's SCN_UPDATEUI).
- (void)syncFromMainTopLine:(tiLine)mainTopLine;

// ── Behaviour settings (mirror the Options dialog) ─────────────────────────
@property(nonatomic) BOOL useBookmark;
@property(nonatomic) BOOL displayComment;
@property(nonatomic) BOOL lineNumbersInResult;
@property(nonatomic) BOOL wrapMode;
@property(nonatomic) BOOL syncScroll;
@property(nonatomic) BOOL dblClickJumpsToEditView;
@property(nonatomic, copy) NSString *resultFontName;
@property(nonatomic) unsigned resultFontSize;

@end

NS_ASSUME_NONNULL_END
