// AnalyseController.h — central plugin controller (macOS).
//
// Owns the NppData handles, the two docked panels (pattern editor + result),
// the plugin menu state, notification routing and settings. This is the macOS
// counterpart of the Windows `AnalysePlugin` class (the MyPlugin callback
// surface), reshaped around AppKit panels and the host's NPPM_DMM_* docking API.

#import <Cocoa/Cocoa.h>
#include "NppPluginInterfaceMac.h"

@class ResultPanelView;
@class PatternEditorView;

NS_ASSUME_NONNULL_BEGIN

@interface AnalyseController : NSObject

+ (instancetype)shared;

// Wiring from PluginEntry.
- (void)setInfo:(NppData)data
      funcItems:(FuncItem *)items
          count:(int)count
showDialogCmdSlot:(int)slot;

- (void)beNotified:(SCNotification *)n;
- (intptr_t)messageProc:(uint32_t)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam;

// Menu commands.
- (void)cmdToggleShowDialog;
- (void)cmdAddSelectionAsPatterns;
- (void)cmdSearchNow;
- (void)cmdShowOptions;
- (void)cmdShowHelp;

// ── Result-panel control ───────────────────────────────────────────────────
// Toggle just the Analyse Result panel (toolbar button on the editor panel).
- (void)toggleResultPanel;
// Make the Analyse Result panel visible if it isn't (called when a search runs).
- (void)ensureResultPanelVisible;
// A panel's NSView left its window (closed via its title-bar X). The host does
// not notify plugins of this, so the panels report it here to keep the menu
// checkmark / visibility flags in sync.
- (void)panelViewDidDetach:(NSView *)view;

// ── Host messaging helpers (used by the panels) ────────────────────────────
// Send to the Notepad++ main handle (NPPM_* messages).
- (intptr_t)npp:(uint32_t)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam;
// Send to the currently-active editor (main or sub) — SCI_* messages.
- (intptr_t)sci:(uint32_t)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam;
// The handle of the currently-active editor view.
- (NppHandle)activeScintilla;
// The host's bookmark marker id (NPPM_GETBOOKMARKID), cached.
- (intptr_t)bookmarkId;
// Plugin's own allocated "match" marker (green #a2c200 left-bar in the change-
// history margin, like Windows) — does not collide with user bookmarks.
- (intptr_t)matchMarkerId;
// Define the match marker + add it to the change-history margin on the active editor.
- (void)ensureMatchMarkerOnActiveEditor;
// Full path of the active document (empty for untitled).
- (NSString *)currentFilePath;
// The plugin's config directory (~/.nextpad++/plugins/Config/AnalysePlugin/).
- (NSString *)configDir;

// Run the multi-pattern search over the active document (port of doSearch).
- (void)doSearch;
// Re-apply NSUserDefaults-backed settings to the panels (called by Options OK).
- (void)applySettings;

@property(nonatomic, readonly) NppData nppData;

@end

NS_ASSUME_NONNULL_END
