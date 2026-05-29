// OptionsWindow.mm — see header. Port of the Windows ConfigDialog (Options).
//
// Layout matches Windows (Image #8): within each group, LABELS are left-aligned
// and CONTROLS (checkboxes, combos, colour wells, buttons) are right-aligned to
// the group's trailing edge.

#import "OptionsWindow.h"
#import "AnalyseController.h"
#include "tclColor.h"

NSString *const kAPDefSearchType  = @"AnalysePlugin.def.searchType";
NSString *const kAPDefMatchCase   = @"AnalysePlugin.def.matchCase";
NSString *const kAPDefWholeWord   = @"AnalysePlugin.def.wholeWord";
NSString *const kAPDefDoSearch    = @"AnalysePlugin.def.doSearch";
NSString *const kAPDefHideText    = @"AnalysePlugin.def.hideText";
NSString *const kAPDefFgColor     = @"AnalysePlugin.def.fgColor";
NSString *const kAPDefBgColor     = @"AnalysePlugin.def.bgColor";
NSString *const kAPDefSelection   = @"AnalysePlugin.def.selection";
NSString *const kAPUseBookmark    = @"AnalysePlugin.useBookmark";
NSString *const kAPAutoUpdate     = @"AnalysePlugin.autoUpdate";
NSString *const kAPSyncScroll     = @"AnalysePlugin.syncScroll";
NSString *const kAPDblClickJumps  = @"AnalysePlugin.dblClickJumps";
NSString *const kAPOnEnterAction  = @"AnalysePlugin.onEnterAction";
NSString *const kAPNumCfgFiles    = @"AnalysePlugin.numCfgFiles";
NSString *const kAPResultFontName = @"AnalysePlugin.resultFontName";
NSString *const kAPResultFontSize = @"AnalysePlugin.resultFontSize";
NSString *const kAPShowLineNumbers= @"AnalysePlugin.showLineNumbers";
NSString *const kAPWordWrap       = @"AnalysePlugin.wordWrap";

static NSColor *nsColorFromRefO(int c) {
    return [NSColor colorWithCalibratedRed:(c & 0xFF) / 255.0
                                     green:((c >> 8) & 0xFF) / 255.0
                                      blue:((c >> 16) & 0xFF) / 255.0 alpha:1.0];
}
static int refFromNSColorO(NSColor *col) {
    NSColor *c = [col colorUsingColorSpace:NSColorSpace.genericRGBColorSpace] ?: col;
    int r = (int)lround(c.redComponent * 255.0), g = (int)lround(c.greenComponent * 255.0),
        b = (int)lround(c.blueComponent * 255.0);
    return (int)RGB(r, g, b);
}

// ── control factories ────────────────────────────────────────────────────────
static NSTextField *lbl(NSString *s) {
    NSTextField *l = [NSTextField labelWithString:s];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}
static NSButton *chkBox(void) {  // title-less checkbox (label lives to its left)
    NSButton *b = [NSButton checkboxWithTitle:@"" target:nil action:nil];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}
static NSPopUpButton *popup(NSArray<NSString *> *titles) {
    NSPopUpButton *p = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [p addItemsWithTitles:titles];
    p.translatesAutoresizingMaskIntoConstraints = NO;
    return p;
}
static NSColorWell *well(void) {
    NSColorWell *w = [[NSColorWell alloc] initWithFrame:NSZeroRect];
    w.translatesAutoresizingMaskIntoConstraints = NO;
    return w;
}
static NSBox *box(NSString *title) {
    NSBox *b = [[NSBox alloc] initWithFrame:NSZeroRect];
    b.title = title;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

@implementation OptionsWindow {
    __weak AnalyseController *_controller;
    NSPopUpButton *_searchType, *_selection, *_onEnter, *_numCfg, *_fontName, *_fontSize;
    NSButton *_matchCase, *_wholeWord, *_doSearch, *_hideText, *_useBookmark, *_autoUpdate,
             *_syncScroll, *_dblClick, *_showLineNo, *_wordWrap;
    NSColorWell *_fgWell, *_bgWell;
}

- (instancetype)initWithController:(AnalyseController *)controller {
    NSRect frame = NSMakeRect(0, 0, 580, 470);
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:frame
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskUtilityWindow)
          backing:NSBackingStoreBuffered defer:NO];
    panel.title = @"Analyse Plugin Options";
    panel.releasedWhenClosed = NO;
    if ((self = [super initWithWindow:panel])) {
        _controller = controller;
        [self buildUI];
        [self loadFromDefaults];
    }
    return self;
}

- (void)buildUI {
    NSView *c = self.window.contentView;

    NSBox *gDef  = box(@"Default Values");
    NSBox *gBeh  = box(@"Behaviour");
    NSBox *gFont = box(@"Result Window Font");

    // Default Values
    _searchType = popup(@[@"normal", @"escaped", @"regex", @"rgx_multiline"]);
    _matchCase = chkBox(); _wholeWord = chkBox(); _doSearch = chkBox(); _hideText = chkBox();
    _fgWell = well(); _bgWell = well();
    _selection = popup(@[@"text", @"line"]);

    // Behaviour
    _useBookmark = chkBox(); _autoUpdate = chkBox(); _syncScroll = chkBox(); _dblClick = chkBox();
    _onEnter = popup(@[@"just search", @"update line", @"add line"]);
    _numCfg = popup(@[@"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8"]);
    NSButton *ctxBtn = [NSButton buttonWithTitle:@"add command" target:self action:@selector(onAddContext:)];
    ctxBtn.translatesAutoresizingMaskIntoConstraints = NO;

    // Result Window Font
    _fontName = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_fontName addItemWithTitle:@""];
    [_fontName addItemsWithTitles:[[NSFontManager sharedFontManager].availableFontFamilies
                                   sortedArrayUsingSelector:@selector(compare:)]];
    _fontName.translatesAutoresizingMaskIntoConstraints = NO;
    _fontSize = popup(@[@"6", @"7", @"8", @"9", @"10", @"11", @"12", @"14", @"16", @"18", @"20"]);
    _showLineNo = chkBox(); _wordWrap = chkBox();

    NSButton *ok = [NSButton buttonWithTitle:@"OK" target:self action:@selector(onOK:)];
    ok.keyEquivalent = @"\r"; ok.translatesAutoresizingMaskIntoConstraints = NO;
    NSButton *cancel = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(onCancel:)];
    cancel.keyEquivalent = @"\033"; cancel.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSView *v in @[gDef, gBeh, gFont, ok, cancel]) [c addSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [gDef.topAnchor constraintEqualToAnchor:c.topAnchor constant:12],
        [gDef.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:12],
        [gDef.widthAnchor constraintEqualToConstant:265],
        [gDef.heightAnchor constraintEqualToConstant:255],

        [gBeh.topAnchor constraintEqualToAnchor:gDef.topAnchor],
        [gBeh.leadingAnchor constraintEqualToAnchor:gDef.trailingAnchor constant:12],
        [gBeh.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-12],
        [gBeh.heightAnchor constraintEqualToConstant:235],

        [gFont.topAnchor constraintEqualToAnchor:gDef.bottomAnchor constant:12],
        [gFont.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:12],
        [gFont.widthAnchor constraintEqualToConstant:265],
        [gFont.heightAnchor constraintEqualToConstant:135],

        [ok.bottomAnchor constraintEqualToAnchor:c.bottomAnchor constant:-12],
        [ok.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-12],
        [ok.widthAnchor constraintEqualToConstant:84],
        [cancel.bottomAnchor constraintEqualToAnchor:c.bottomAnchor constant:-12],
        [cancel.trailingAnchor constraintEqualToAnchor:ok.leadingAnchor constant:-10],
        [cancel.widthAnchor constraintEqualToConstant:84],
    ]];

    [self layoutGroup:gDef.contentView rows:@[
        @[lbl(@"Search type"),           _searchType],
        @[lbl(@"Search case sensitive"), _matchCase],
        @[lbl(@"Search whole word"),     _wholeWord],
        @[lbl(@"Do Search"),             _doSearch],
        @[lbl(@"Hide text"),             _hideText],
        @[lbl(@"Color Foreground"),      _fgWell],
        @[lbl(@"Color Background"),      _bgWell],
        @[lbl(@"Selection on"),          _selection],
    ]];
    [self layoutGroup:gBeh.contentView rows:@[
        @[lbl(@"Use bookmarks in text"),       _useBookmark],
        @[lbl(@"Auto update on modify"),       _autoUpdate],
        @[lbl(@"Synchronize view scrolling"),  _syncScroll],
        @[lbl(@"Dbl-Click jumps to EditView"), _dblClick],
        @[lbl(@"Action on Enter"),             _onEnter],
        @[lbl(@"Recently used config files"),  _numCfg],
        @[lbl(@"Editor context menu"),         ctxBtn],
    ]];
    [self layoutGroup:gFont.contentView rows:@[
        @[lbl(@"Name"),                        _fontName],
        @[lbl(@"Size"),                        _fontSize],
        @[lbl(@"Show line numbers in result"), _showLineNo],
        @[lbl(@"Word wrap mode in result"),    _wordWrap],
    ]];
}

// Each row: label left-aligned, control right-aligned to the group trailing edge.
- (void)layoutGroup:(NSView *)g rows:(NSArray<NSArray<NSView *> *> *)rows {
    NSView *prev = nil;
    for (NSArray<NSView *> *row in rows) {
        NSTextField *label = (NSTextField *)row[0];
        NSView *control = row[1];
        [g addSubview:label];
        [g addSubview:control];

        [label.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:12].active = YES;
        [control.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-12].active = YES;
        [label.centerYAnchor constraintEqualToAnchor:control.centerYAnchor].active = YES;
        // keep the label from overlapping the control
        [control.leadingAnchor constraintGreaterThanOrEqualToAnchor:label.trailingAnchor constant:8].active = YES;

        if (prev) [control.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:8].active = YES;
        else      [control.topAnchor constraintEqualToAnchor:g.topAnchor constant:8].active = YES;

        if ([control isKindOfClass:NSColorWell.class]) {
            [control.widthAnchor constraintEqualToConstant:44].active = YES;
            [control.heightAnchor constraintEqualToConstant:20].active = YES;
        }
        prev = control;
    }
}

- (void)loadFromDefaults {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [_searchType selectItemAtIndex:[d integerForKey:kAPDefSearchType]];
    _matchCase.state = [d boolForKey:kAPDefMatchCase];
    _wholeWord.state = [d boolForKey:kAPDefWholeWord];
    _doSearch.state  = [d boolForKey:kAPDefDoSearch];
    _hideText.state  = [d boolForKey:kAPDefHideText];
    _fgWell.color = nsColorFromRefO((int)[d integerForKey:kAPDefFgColor]);
    _bgWell.color = nsColorFromRefO((int)[d integerForKey:kAPDefBgColor]);
    [_selection selectItemAtIndex:[d integerForKey:kAPDefSelection]];
    _useBookmark.state = [d boolForKey:kAPUseBookmark];
    _autoUpdate.state  = [d boolForKey:kAPAutoUpdate];
    _syncScroll.state  = [d boolForKey:kAPSyncScroll];
    _dblClick.state    = [d boolForKey:kAPDblClickJumps];
    [_onEnter selectItemAtIndex:[d integerForKey:kAPOnEnterAction]];
    [_numCfg selectItemWithTitle:[NSString stringWithFormat:@"%ld", (long)[d integerForKey:kAPNumCfgFiles]]];
    NSString *fn = [d stringForKey:kAPResultFontName] ?: @"";
    if (fn.length && [_fontName itemWithTitle:fn]) [_fontName selectItemWithTitle:fn];
    else [_fontName selectItemAtIndex:0];
    [_fontSize selectItemWithTitle:[NSString stringWithFormat:@"%ld", (long)[d integerForKey:kAPResultFontSize]]];
    _showLineNo.state = [d boolForKey:kAPShowLineNumbers];
    _wordWrap.state   = [d boolForKey:kAPWordWrap];
}

- (void)onOK:(id)sender {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setInteger:_searchType.indexOfSelectedItem forKey:kAPDefSearchType];
    [d setBool:(_matchCase.state == NSControlStateValueOn) forKey:kAPDefMatchCase];
    [d setBool:(_wholeWord.state == NSControlStateValueOn) forKey:kAPDefWholeWord];
    [d setBool:(_doSearch.state == NSControlStateValueOn) forKey:kAPDefDoSearch];
    [d setBool:(_hideText.state == NSControlStateValueOn) forKey:kAPDefHideText];
    [d setInteger:refFromNSColorO(_fgWell.color) forKey:kAPDefFgColor];
    [d setInteger:refFromNSColorO(_bgWell.color) forKey:kAPDefBgColor];
    [d setInteger:_selection.indexOfSelectedItem forKey:kAPDefSelection];
    [d setBool:(_useBookmark.state == NSControlStateValueOn) forKey:kAPUseBookmark];
    [d setBool:(_autoUpdate.state == NSControlStateValueOn) forKey:kAPAutoUpdate];
    [d setBool:(_syncScroll.state == NSControlStateValueOn) forKey:kAPSyncScroll];
    [d setBool:(_dblClick.state == NSControlStateValueOn) forKey:kAPDblClickJumps];
    [d setInteger:_onEnter.indexOfSelectedItem forKey:kAPOnEnterAction];
    [d setInteger:_numCfg.titleOfSelectedItem.intValue forKey:kAPNumCfgFiles];
    [d setObject:(_fontName.titleOfSelectedItem ?: @"") forKey:kAPResultFontName];
    [d setInteger:_fontSize.titleOfSelectedItem.intValue forKey:kAPResultFontSize];
    [d setBool:(_showLineNo.state == NSControlStateValueOn) forKey:kAPShowLineNumbers];
    [d setBool:(_wordWrap.state == NSControlStateValueOn) forKey:kAPWordWrap];
    [_controller applySettings];
    [self.window close];
}

- (void)onCancel:(id)sender { [self.window close]; }

- (void)onAddContext:(id)sender {
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = @"Editor context-menu command";
    a.informativeText = @"To add Analyse Plugin commands to the editor context menu, add "
                         "<Item> entries referencing the plugin's menu items to your "
                         "contextMenu.xml in the Nextpad++ config folder.";
    [a runModal];
}

- (void)showModal {
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];   // non-modal; controller keeps a strong ref
}

@end
