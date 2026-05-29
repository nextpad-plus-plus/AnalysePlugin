// PatternEditorView.mm — see header. (Full table/controls UI lands in a later pass;
// this provides the model + Add-selection / Search-now so the engine works E2E.)

#import "PatternEditorView.h"
#import "AnalyseController.h"
#include "Scintilla.h"
#include "tclColor.h"

@implementation PatternEditorView {
    __weak AnalyseController *_controller;
    tclResultList _resultList;
    tclPattern    _defaultPattern;
    NSTextField  *_placeholder;
}

- (instancetype)initWithController:(AnalyseController *)controller {
    if ((self = [super initWithFrame:NSMakeRect(0, 0, 360, 600)])) {
        _controller = controller;

        _placeholder = [NSTextField labelWithString:@"Analyse Plugin"];
        _placeholder.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_placeholder];
        [NSLayoutConstraint activateConstraints:@[
            [_placeholder.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_placeholder.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        ]];
    }
    return self;
}

- (tclResultList &)resultListRef { return _resultList; }
- (const tclPattern &)defaultPattern { return _defaultPattern; }

// Split the active editor's selection into lines and add each as a pattern,
// cycling foreground colours through the named-colour palette (port of the
// Windows "Add selection as patterns").
- (void)addSelectionAsPatterns {
    intptr_t len = [_controller sci:SCI_GETSELTEXT wParam:0 lParam:0];
    if (len <= 1) return;                       // nothing selected
    std::string buf;
    buf.resize((size_t)len + 1);                // room for Scintilla's NUL
    [_controller sci:SCI_GETSELTEXT wParam:0 lParam:(intptr_t)&buf[0]];
    buf.resize(strlen(buf.c_str()));            // trim to actual text

    NSString *sel = [NSString stringWithUTF8String:buf.c_str()] ?: @"";
    NSArray<NSString *> *lines = [sel componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet newlineCharacterSet]];
    int colorIdx = 0;
    int nColors = tclColor::getDefColorListSize();
    for (NSString *raw in lines) {
        NSString *line = [raw stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceCharacterSet]];
        if (line.length == 0) continue;
        tclPattern p = _defaultPattern;
        p.setSearchText(line.UTF8String);
        // assign a rotating foreground colour from the palette
        p.setColor(tclColor::getDefColorNum(colorIdx % nColors));
        ++colorIdx;
        _resultList.push_back(p);
    }
    [self runSearch];
}

- (void)runSearch {
    [_controller doSearch];
}

@end
