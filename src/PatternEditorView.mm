// PatternEditorView.mm — Phase-4 placeholder. See header.

#import "PatternEditorView.h"
#import "AnalyseController.h"

@implementation PatternEditorView {
    __weak AnalyseController *_controller;
}

- (instancetype)initWithController:(AnalyseController *)controller {
    if ((self = [super initWithFrame:NSMakeRect(0, 0, 360, 600)])) {
        _controller = controller;

        NSTextField *label = [NSTextField labelWithString:@"Analyse Plugin (pattern editor — building…)"];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:label];
        [NSLayoutConstraint activateConstraints:@[
            [label.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [label.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        ]];
    }
    return self;
}

- (void)addSelectionAsPatterns { NSLog(@"[AnalysePlugin] addSelectionAsPatterns (pending)"); }
- (void)runSearch { NSLog(@"[AnalysePlugin] runSearch (pending)"); }

@end
