// AnalyseController.mm — see header.

#import "AnalyseController.h"
#import "ResultPanelView.h"
#import "PatternEditorView.h"
#include "Scintilla.h"

extern NppData nppData;

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
    _items = items;
    _itemCount = count;
    _showDialogSlot = slot;
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
            [self ensurePanels];
            [self setPanelsVisible:YES];
            break;
        case NPPN_SHUTDOWN:
            if (_editorHandle) [self npp:NPPM_DMM_UNREGISTERPANEL wParam:(uintptr_t)_editorHandle lParam:0];
            if (_resultHandle) [self npp:NPPM_DMM_UNREGISTERPANEL wParam:(uintptr_t)_resultHandle lParam:0];
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
    // OptionsWindow lands in a later phase.
    NSLog(@"[AnalysePlugin] Options… (pending)");
}

- (void)cmdShowHelp {
    // HelpWindow lands in a later phase.
    NSLog(@"[AnalysePlugin] Help… (pending)");
}

@end
