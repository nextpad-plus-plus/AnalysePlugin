// ResultPanelView.h — the "Analyse Result" docked panel.
//
// An NSView that embeds a real Scintilla editor (the host's ScintillaView,
// resolved at runtime from the host process) to render search results with
// per-pattern container styling, exactly like the Windows result window.

#import <Cocoa/Cocoa.h>

@class AnalyseController;

NS_ASSUME_NONNULL_BEGIN

@interface ResultPanelView : NSView

- (instancetype)initWithController:(AnalyseController *)controller;

// Send a Scintilla message to the embedded result editor.
- (intptr_t)sci:(uint32_t)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam;

// Replace the whole result text (UTF-8).
- (void)setResultText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
