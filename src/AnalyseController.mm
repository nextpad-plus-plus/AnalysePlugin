// AnalyseController.mm — see header.

#import "AnalyseController.h"
#import "ResultPanelView.h"
#import "PatternEditorView.h"
#import "OptionsWindow.h"
#import "HelpWindow.h"
#include "Scintilla.h"
#include "BoostRegexSearch.h"   // SCFIND_REGEXP_DOTMATCHESNL / EMPTYMATCH_ALL / SKIPCRLFASONE
#include "tclPattern.h"
#include "tclResult.h"
#include "tclResultList.h"
#include <vector>

extern NppData nppData;

@interface AnalyseController ()
// Search one pattern over the active document; fills result. Returns hit count.
- (int)findPattern:(const tclPattern &)pattern into:(tclResult &)result;
// Auto-persisted pattern list file (~/.nextpad++/plugins/Config/AnalysePlugin/AnalysePlugin.xml).
- (NSString *)autoConfigPath;
@end

@implementation AnalyseController {
    FuncItem *_items;          // owned by PluginEntry (static storage)
    int       _itemCount;
    int       _showDialogSlot;

    PatternEditorView *_editorPanel;
    ResultPanelView   *_resultPanel;
    uint64_t           _editorHandle;
    uint64_t           _resultHandle;
    BOOL               _panelsVisible;
    BOOL               _ready;

    intptr_t  _bookmarkId;
    BOOL      _bookmarkIdResolved;
    NSString *_lastSearchFile;
    OptionsWindow *_optionsWindow;
    HelpWindow    *_helpWindow;
}

// Default settings (mirror the Windows ConfigDialog ctor + Image #2).
+ (void)registerDefaults {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kAPDefSearchType: @0, kAPDefMatchCase: @NO, kAPDefWholeWord: @NO,
        kAPDefDoSearch: @YES, kAPDefHideText: @NO,
        kAPDefFgColor: @(0), kAPDefBgColor: @(0xFFFFFF), kAPDefSelection: @1 /*line*/,
        kAPUseBookmark: @YES, kAPAutoUpdate: @NO, kAPSyncScroll: @YES, kAPDblClickJumps: @YES,
        kAPOnEnterAction: @0, kAPNumCfgFiles: @4,
        kAPResultFontName: @"", kAPResultFontSize: @8,
        kAPShowLineNumbers: @YES, kAPWordWrap: @NO,
    }];
}

+ (instancetype)shared {
    static AnalyseController *g;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ g = [[AnalyseController alloc] init]; });
    return g;
}

- (NppData)nppData { return nppData; }

- (void)setInfo:(NppData)data
      funcItems:(FuncItem *)items
          count:(int)count
showDialogCmdSlot:(int)slot {
    [AnalyseController registerDefaults];
    _items = items;
    _itemCount = count;
    _showDialogSlot = slot;
}

// Push NSUserDefaults-backed settings into the panels + default pattern, then
// re-render (a full doSearch rebuilds result text/styles with the new options).
- (void)applySettings {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    if (_resultPanel) {
        _resultPanel.useBookmark = [d boolForKey:kAPUseBookmark];
        _resultPanel.syncScroll = [d boolForKey:kAPSyncScroll];
        _resultPanel.dblClickJumpsToEditView = [d boolForKey:kAPDblClickJumps];
        _resultPanel.lineNumbersInResult = [d boolForKey:kAPShowLineNumbers];
        _resultPanel.wrapMode = [d boolForKey:kAPWordWrap];
        _resultPanel.resultFontName = [d stringForKey:kAPResultFontName] ?: @"";
        _resultPanel.resultFontSize = (unsigned)[d integerForKey:kAPResultFontSize];
    }
    if (_editorPanel) {
        tclPattern dp;
        dp.setSearchType((int)[d integerForKey:kAPDefSearchType]);
        dp.setMatchCase([d boolForKey:kAPDefMatchCase]);
        dp.setWholeWord([d boolForKey:kAPDefWholeWord]);
        dp.setDoSearch([d boolForKey:kAPDefDoSearch]);
        dp.setHideText([d boolForKey:kAPDefHideText]);
        dp.setColor((tColor)[d integerForKey:kAPDefFgColor]);
        dp.setBgColor((tColor)[d integerForKey:kAPDefBgColor]);
        dp.setSelectionType((int)[d integerForKey:kAPDefSelection]);
        [_editorPanel setDefaultPattern:dp];
    }
    if (_ready) [self doSearch];   // re-render with the new display settings
}

// ── Host messaging helpers ─────────────────────────────────────────────────
- (intptr_t)npp:(uint32_t)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam {
    if (!nppData._sendMessage) return 0;
    return nppData._sendMessage(nppData._nppHandle, msg, wParam, lParam);
}

- (NppHandle)activeScintilla {
    int which = 0;
    [self npp:NPPM_GETCURRENTSCINTILLA wParam:0 lParam:(intptr_t)&which];
    return which == 1 ? nppData._scintillaSecondHandle : nppData._scintillaMainHandle;
}

- (intptr_t)sci:(uint32_t)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam {
    if (!nppData._sendMessage) return 0;
    return nppData._sendMessage([self activeScintilla], msg, wParam, lParam);
}

- (NSString *)configDir {
    char buf[2048] = {0};
    [self npp:NPPM_GETPLUGINSCONFIGDIR wParam:sizeof(buf) lParam:(intptr_t)buf];
    NSString *parent = (buf[0] != 0)
        ? @(buf)
        : [NSHomeDirectory() stringByAppendingPathComponent:@".nextpad++/plugins/Config"];
    NSString *dir = [parent stringByAppendingPathComponent:@"AnalysePlugin"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return dir;
}

- (NSString *)autoConfigPath {
    return [[self configDir] stringByAppendingPathComponent:@"AnalysePlugin.xml"];
}

- (intptr_t)bookmarkId {
    // The macOS host draws bookmarks with marker 20 (kBookmarkMarker) and its
    // symbol-margin mask only includes 20/19/18. NPPM_GETBOOKMARKID currently
    // reports 24 (not rendered), so adding marker 24 would be invisible. Use 20
    // to match what the host actually paints in the bookmark margin.
    return 20;
}

- (NSString *)currentFilePath {
    char buf[4096] = {0};
    [self npp:NPPM_GETFULLCURRENTPATH wParam:sizeof(buf) lParam:(intptr_t)buf];
    return buf[0] ? @(buf) : @"";
}

// ── Search engine (port of AnalysePlugin::doSearch) ────────────────────────
- (void)doSearch {
    if (!_editorPanel || !_resultPanel) return;
    tclResultList &rl = [_editorPanel resultListRef];

    // Program style slots from the current patterns + default pattern.
    [_resultPanel setPatternStyles:rl defaultPattern:[_editorPanel defaultPattern]];

    NSString *path = [self currentFilePath];
    [_resultPanel setSearchFileName:path];

    // Line-number column width from the active document's line count.
    tiLine numLines = [self sci:SCI_GETLINECOUNT wParam:0 lParam:0];
    int colSize = (numLines < 10) ? 1 : (numLines < 100) ? 2 : (numLines < 1000) ? 3
                : (numLines < 10000) ? 4 : (numLines < 100000) ? 5 : (numLines < 1000000) ? 6
                : (numLines < 10000000) ? 7 : (numLines < 100000000) ? 8
                : (numLines < 1000000000) ? 9 : 10;

    BOOL bReSearch = NO;
    if (![path isEqualToString:(_lastSearchFile ?: @"")]) { _lastSearchFile = [path copy]; bReSearch = YES; }
    if ([_resultPanel lineNumColSize] != colSize) { [_resultPanel setLineNumColSize:colSize]; bReSearch = YES; }
    if (rl.getIsDirty() == false) bReSearch = YES;   // all clean → full re-search

    if (bReSearch) {
        [_resultPanel clearResults:NO];
        for (tclResultList::iterator it = rl.begin(); it != rl.end(); ++it)
            it.refResult().setDirty(true);
    }

    unsigned commentWidth = rl.getCommentWidth();
    tiLine lcount = [self sci:SCI_GETLINECOUNT wParam:0 lParam:0];

    for (tclResultList::iterator iResult = rl.begin(); iResult != rl.end(); ++iResult) {
        tclResult &result = iResult.refResult();
        if (result.getIsDirty() == false) continue;

        tclResult oldResult = result;
        result.clear();
        const tclPattern &pattern = rl.getPattern(iResult.getPatId());
        unsigned u = (unsigned)[self findPattern:pattern into:result];

        if (u) {
            [_resultPanel reserveLines:u];
            [_resultPanel removeUnusedResultLines:iResult.getPatId() old:oldResult new:result];
            std::string comment = pattern.getComment();   // already UTF-8

            const tclResult::tlvPosInfo &positions = result.getPositions();
            for (tclResult::tlvPosInfo::const_iterator it = positions.begin(); it != positions.end(); ++it) {
                if (it->line >= lcount) continue;     // out of range guard
                [_resultPanel insertPosInfo:iResult.getPatId() line:it->line pos:*it];
                if (![_resultPanel lineAvail:it->line]) {
                    tiLine lend = [self sci:SCI_GETLINEENDPOSITION wParam:(uintptr_t)it->line lParam:0];
                    tiLine lstart = [self sci:SCI_POSITIONFROMLINE wParam:(uintptr_t)it->line lParam:0];
                    int lineLength = (int)(lend - lstart);
                    if (lineLength < 0) lineLength = 0;
                    std::vector<char> lbuf((size_t)lineLength + 3, 0);
                    [self sci:SCI_GETLINE wParam:(uintptr_t)it->line lParam:(intptr_t)lbuf.data()];
                    for (int i = 0; i < lineLength; ++i)
                        if (lbuf[i] == 0) lbuf[i] = 0x20;   // no embedded NULs
                    lbuf[lineLength]     = 0x0D;
                    lbuf[lineLength + 1] = 0x0A;
                    std::string lineText(lbuf.data(), (size_t)lineLength + 2);  // text + CRLF
                    [_resultPanel setLineText:it->line text:lineText comment:comment commentWidth:commentWidth];
                }
            }
        } else {
            [_resultPanel removeUnusedResultLines:iResult.getPatId() old:oldResult new:result];
        }
        [_resultPanel updateAfterSearch];
    }
}

// Port of AnalysePlugin::doFindPattern. macOS: doc + generic_string are UTF-8,
// so the Windows WcharMbcsConvertor wchar→char step is dropped entirely.
- (int)findPattern:(const tclPattern &)pattern into:(tclResult &)result {
    if (pattern.getDoSearch() == false) { result.clear(); result.setDirty(false); return 0; }

    tiLine startRange = 0;
    tiLine endRange = [self sci:SCI_GETLENGTH wParam:0 lParam:0];
    if (endRange < 1) return 0;

    int flags = 0;
    std::string text;
    switch (pattern.getSearchType()) {
        case tclPattern::regex:
            flags |= (SCFIND_REGEXP | SCFIND_POSIX); text = pattern.getSearchText(); break;
        case tclPattern::rgx_multiline:
            flags |= (SCFIND_REGEXP | SCFIND_POSIX | SCFIND_REGEXP_DOTMATCHESNL);
            text = pattern.getSearchText(); break;
        case tclPattern::escaped:
            text = pattern.getSearchTextConverted(); break;   // convertExtendedToString
        default:
            text = pattern.getSearchText(); break;
    }
    flags |= pattern.getIsMatchCase() ? SCFIND_MATCHCASE : 0;
    flags |= pattern.getIsWholeWord() ? SCFIND_WHOLEWORD : 0;
    flags |= SCFIND_REGEXP_EMPTYMATCH_ALL | SCFIND_REGEXP_SKIPCRLFASONE;

    if (text.empty()) { result.setDirty(false); return 0; }

    [self sci:SCI_SETTARGETSTART wParam:(uintptr_t)startRange lParam:0];
    [self sci:SCI_SETTARGETEND wParam:(uintptr_t)endRange lParam:0];
    [self sci:SCI_SETSEARCHFLAGS wParam:(uintptr_t)flags lParam:0];

    int nb = 0;
    tiLine targetStart = [self sci:SCI_SEARCHINTARGET wParam:text.size() lParam:(intptr_t)text.c_str()];
    while (targetStart >= 0) {
        if (targetStart == 0) {
            int st = (int)[self sci:SCI_GETSTATUS wParam:0 lParam:0];
            if (st != 0 && st != SC_STATUS_OK) {
                [self sci:SCI_SETSTATUS wParam:SC_STATUS_OK lParam:0];   // clear
                break;
            }
        }
        targetStart = [self sci:SCI_GETTARGETSTART wParam:0 lParam:0];
        tiLine targetEnd = [self sci:SCI_GETTARGETEND wParam:0 lParam:0];
        if (targetEnd > endRange) break;
        int foundTextLen = (int)(targetEnd - targetStart);

        tiLine lineNumberStart = [self sci:SCI_LINEFROMPOSITION wParam:(uintptr_t)targetStart lParam:0];
        tiLine lineNumberEnd = [self sci:SCI_LINEFROMPOSITION wParam:(uintptr_t)targetEnd lParam:0];
        for (tiLine li = lineNumberStart; li <= lineNumberEnd; ++li)
            result.push_back((int)targetStart, (int)targetEnd, (int)li);

        // Advance. Guard against zero-length (empty regex) matches looping forever.
        startRange = targetStart + (foundTextLen > 0 ? foundTextLen : 1);
        if (startRange > endRange) break;
        [self sci:SCI_SETTARGETSTART wParam:(uintptr_t)startRange lParam:0];
        [self sci:SCI_SETTARGETEND wParam:(uintptr_t)endRange lParam:0];
        ++nb;
        targetStart = [self sci:SCI_SEARCHINTARGET wParam:text.size() lParam:(intptr_t)text.c_str()];
    }
    result.setDirty(false);
    return nb;
}

// ── Panels ─────────────────────────────────────────────────────────────────
- (void)ensurePanels {
    if (_editorPanel) return;

    _editorPanel = [[PatternEditorView alloc] initWithController:self];
    _resultPanel = [[ResultPanelView alloc] initWithController:self];

    _editorHandle = (uint64_t)[self npp:NPPM_DMM_REGISTERPANEL
                                 wParam:(uintptr_t)(__bridge void *)_editorPanel
                                 lParam:(intptr_t) "Analyse Plugin"];
    _resultHandle = (uint64_t)[self npp:NPPM_DMM_REGISTERPANEL
                                 wParam:(uintptr_t)(__bridge void *)_resultPanel
                                 lParam:(intptr_t) "Analyse Result"];
}

- (void)setPanelsVisible:(BOOL)visible {
    [self ensurePanels];
    uint32_t msg = visible ? NPPM_DMM_SHOWPANEL : NPPM_DMM_HIDEPANEL;
    if (_editorHandle) [self npp:msg wParam:(uintptr_t)_editorHandle lParam:0];
    if (_resultHandle) [self npp:msg wParam:(uintptr_t)_resultHandle lParam:0];
    _panelsVisible = visible;
    [self syncMenuCheck];
}

- (void)syncMenuCheck {
    if (!_items || _showDialogSlot < 0 || _showDialogSlot >= _itemCount) return;
    int cmdID = _items[_showDialogSlot]._cmdID;
    if (cmdID != 0)
        [self npp:NPPM_SETMENUITEMCHECK wParam:(uintptr_t)cmdID lParam:(_panelsVisible ? 1 : 0)];
}

// ── Notifications ───────────────────────────────────────────────────────────
- (void)beNotified:(SCNotification *)n {
    if (!n) return;
    switch (n->nmhdr.code) {
        case NPPN_READY:
            _ready = YES;
            // Register both panels (they come back HIDDEN). We deliberately do
            // NOT auto-show here: showing at READY doesn't reliably "take"
            // before the side-panel host / session restore has settled, which
            // would leave the menu checkmark ON while the panels stay hidden.
            // Start hidden + unchecked so the first click shows them in sync.
            [self ensurePanels];
            [_editorPanel loadFromPath:[self autoConfigPath]];   // restore last pattern list
            [self applySettings];                                // apply saved options to panels
            _panelsVisible = NO;
            [self syncMenuCheck];
            break;
        case NPPN_SHUTDOWN:
            [_editorPanel saveToPath:[self autoConfigPath]];     // persist pattern list
            if (_editorHandle) [self npp:NPPM_DMM_UNREGISTERPANEL wParam:(uintptr_t)_editorHandle lParam:0];
            if (_resultHandle) [self npp:NPPM_DMM_UNREGISTERPANEL wParam:(uintptr_t)_resultHandle lParam:0];
            break;
        case SCN_UPDATEUI:
            // Mirror the main editor's vertical scroll into the result window.
            if (_resultPanel && (n->updated & SC_UPDATE_V_SCROLL)) {
                tiLine top = [self sci:SCI_GETFIRSTVISIBLELINE wParam:0 lParam:0];
                [_resultPanel syncFromMainTopLine:top];
            }
            break;
        default:
            break;
    }
}

- (intptr_t)messageProc:(uint32_t)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam {
    return 0;
}

// ── Menu commands ───────────────────────────────────────────────────────────
- (void)cmdToggleShowDialog {
    [self setPanelsVisible:!_panelsVisible];
}

- (void)cmdAddSelectionAsPatterns {
    [self ensurePanels];
    [_editorPanel addSelectionAsPatterns];
}

- (void)cmdSearchNow {
    [self ensurePanels];
    [_editorPanel runSearch];
}

- (void)cmdShowOptions {
    _optionsWindow = [[OptionsWindow alloc] initWithController:self];  // strong ref keeps it alive
    [_optionsWindow showModal];
}

- (void)cmdShowHelp {
    _helpWindow = [[HelpWindow alloc] init];   // strong ref keeps it alive
    [_helpWindow showHelp];
}

@end
