// PluginEntry.mm — the 5 C entry points the host loads via dlsym.
//
// Mirrors the Windows AnalysePlugin.cpp DLL exports. The menu layout matches
// the Windows plugin menu exactly:
//
//   ✓ Show Analyse Dialog        (checkable — tracks panel visibility)
//   ─────────
//     Add selection as patterns
//     Search now
//   ─────────
//     Options…
//     Help…
//
// All real work lives in AnalyseController.

#include "NppPluginInterfaceMac.h"
#include "Scintilla.h"
#import <Foundation/Foundation.h>

#import "AnalyseController.h"

// Global NppData so the SendMessage(...) compat macro in NppPluginInterfaceMac.h
// resolves for every translation unit that declares `extern NppData nppData;`.
NppData nppData = {};

// ── Menu slots ──────────────────────────────────────────────────────────────
enum {
    MNU_SHOW_DIALOG = 0,   // checkable
    MNU_SEP1,
    MNU_ADD_SELECTION,
    MNU_SEARCH_NOW,
    MNU_SEP2,
    MNU_OPTIONS,
    MNU_HELP,
    MNU_TOTAL
};

static FuncItem _items[MNU_TOTAL];

// ── Command thunks ────────────────────────────────────────────────────────
static void cbShowDialog(void)   { [[AnalyseController shared] cmdToggleShowDialog]; }
static void cbAddSelection(void) { [[AnalyseController shared] cmdAddSelectionAsPatterns]; }
static void cbSearchNow(void)    { [[AnalyseController shared] cmdSearchNow]; }
static void cbOptions(void)      { [[AnalyseController shared] cmdShowOptions]; }
static void cbHelp(void)         { [[AnalyseController shared] cmdShowHelp]; }

static void setName(FuncItem *fi, NSString *s) {
    memset(fi->_itemName, 0, NPP_MENU_ITEM_SIZE);
    if (s) strlcpy(fi->_itemName, s.UTF8String ?: "", NPP_MENU_ITEM_SIZE);
}

static void buildFuncItems(void) {
    memset(_items, 0, sizeof _items);

    setName(&_items[MNU_SHOW_DIALOG], @"Show Analyse Dialog");
    _items[MNU_SHOW_DIALOG]._pFunc = cbShowDialog;
    _items[MNU_SHOW_DIALOG]._init2Check = false;   // updated on NPPN_READY

    // MNU_SEP1: separator (NULL func + empty name)

    setName(&_items[MNU_ADD_SELECTION], @"Add selection as patterns");
    _items[MNU_ADD_SELECTION]._pFunc = cbAddSelection;

    setName(&_items[MNU_SEARCH_NOW], @"Search now");
    _items[MNU_SEARCH_NOW]._pFunc = cbSearchNow;

    // MNU_SEP2: separator

    setName(&_items[MNU_OPTIONS], @"Options…");
    _items[MNU_OPTIONS]._pFunc = cbOptions;

    setName(&_items[MNU_HELP], @"Help…");
    _items[MNU_HELP]._pFunc = cbHelp;
}

// ── C exports ────────────────────────────────────────────────────────────
extern "C" NPP_EXPORT void setInfo(NppData data) {
    nppData = data;
    buildFuncItems();
    [[AnalyseController shared] setInfo:data funcItems:_items count:MNU_TOTAL
                       showDialogCmdSlot:MNU_SHOW_DIALOG];
}

extern "C" NPP_EXPORT const char *getName(void) {
    return "Analyse Plugin";
}

extern "C" NPP_EXPORT FuncItem *getFuncsArray(int *nbF) {
    if (nbF) *nbF = MNU_TOTAL;
    return _items;
}

extern "C" NPP_EXPORT void beNotified(SCNotification *n) {
    [[AnalyseController shared] beNotified:n];
}

extern "C" NPP_EXPORT intptr_t messageProc(uint32_t msg, uintptr_t wParam, intptr_t lParam) {
    return [[AnalyseController shared] messageProc:msg wParam:wParam lParam:lParam];
}
