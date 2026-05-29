// ResultPanelView.mm — see header.

#import "ResultPanelView.h"
#import "AnalyseController.h"
#import "ScintillaView.h"
#include "Scintilla.h"

@interface ResultPanelView () <ScintillaNotificationProtocol>
@end

@implementation ResultPanelView {
    __weak AnalyseController *_controller;
    ScintillaView *_sci;          // host class, resolved at runtime
}

- (instancetype)initWithController:(AnalyseController *)controller {
    if ((self = [super initWithFrame:NSMakeRect(0, 0, 900, 240)])) {
        _controller = controller;
        [self buildScintilla];
    }
    return self;
}

- (void)buildScintilla {
    // The ScintillaView class is statically linked into the host executable;
    // resolve it from the running process rather than link against it. This
    // keeps the plugin self-contained and coupled only to the message API.
    Class scintillaClass = NSClassFromString(@"ScintillaView");
    if (!scintillaClass) {
        NSLog(@"[AnalysePlugin] ScintillaView class unavailable in host process");
        return;
    }

    _sci = [[scintillaClass alloc] initWithFrame:self.bounds];
    _sci.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self addSubview:_sci];
    _sci.delegate = self;

    // Read-only results view, container-styled (we apply styles ourselves).
    [self sci:SCI_SETILEXER wParam:0 lParam:(intptr_t)0];   // SCLEX_CONTAINER == 0
    [self sci:SCI_SETREADONLY wParam:1 lParam:0];
    [self sci:SCI_SETMARGINWIDTHN wParam:1 lParam:0];        // no symbol margin (yet)
    [self sci:SCI_USEPOPUP wParam:0 lParam:0];               // we provide our own menu

    [self setResultText:@""];
}

- (intptr_t)sci:(uint32_t)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam {
    if (!_sci) return 0;
    return [_sci message:msg wParam:wParam lParam:lParam];
}

- (void)setResultText:(NSString *)text {
    const char *utf8 = text.UTF8String ?: "";
    BOOL wasRO = (BOOL)[self sci:SCI_GETREADONLY wParam:0 lParam:0];
    if (wasRO) [self sci:SCI_SETREADONLY wParam:0 lParam:0];
    [self sci:SCI_SETTEXT wParam:0 lParam:(intptr_t)utf8];
    if (wasRO) [self sci:SCI_SETREADONLY wParam:1 lParam:0];
}

// ── ScintillaNotificationProtocol ──────────────────────────────────────────
- (void)notification:(SCNotification *)notification {
    if (!notification) return;
    // Double-click → jump handling lands in a later phase.
}

@end
