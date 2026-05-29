// OptionsWindow.mm — see header. Port of the Windows ConfigDialog (Options).

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

@implementation OptionsWindow {
    __weak AnalyseController *_controller;
    NSPopUpButton *_searchType, *_selection, *_onEnter, *_numCfg, *_fontName, *_fontSize;
    NSButton *_matchCase, *_wholeWord, *_doSearch, *_hideText, *_useBookmark, *_autoUpdate,
             *_syncScroll, *_dblClick, *_showLineNo, *_wordWrap;
    NSColorWell *_fgWell, *_bgWell;
}

- (instancetype)initWithController:(AnalyseController *)controller {
    NSRect frame = NSMakeRect(0, 0, 560, 460);
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

static NSTextField *lbl(NSString *s) {
    NSTextField *l = [NSTextField labelWithString:s];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}
static NSButton *chk(NSString *t) {
    NSButton *b = [NSButton checkboxWithTitle:t target:nil action:nil];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}
static NSBox *box(NSString *title) {
    NSBox *b = [[NSBox alloc] initWithFrame:NSZeroRect];
    b.title = title;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

- (void)buildUI {
    NSView *c = self.window.contentView;

    // ── Default Values group ────────────────────────────────────────────────
    NSBox *gDef = box(@"Default Values");
    NSView *dv = gDef.contentView;
    NSTextField *typeLbl = lbl(@"Search type");
    _searchType = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_searchType addItemsWithTitles:@[@"normal", @"escaped", @"regex", @"rgx_multiline"]];
    _searchType.translatesAutoresizingMaskIntoConstraints = NO;
    _matchCase = chk(@"Search case sensitive");
    _wholeWord = chk(@"Search whole word");
    _doSearch  = chk(@"Do Search");
    _hideText  = chk(@"Hide text");
    NSTextField *fgLbl = lbl(@"Color Foreground");
    _fgWell = [[NSColorWell alloc] initWithFrame:NSZeroRect]; _fgWell.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *bgLbl = lbl(@"Color Background");
    _bgWell = [[NSColorWell alloc] initWithFrame:NSZeroRect]; _bgWell.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *selLbl = lbl(@"Selection on");
    _selection = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_selection addItemsWithTitles:@[@"text", @"line"]];
    _selection.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSView *v in @[typeLbl,_searchType,_matchCase,_wholeWord,_doSearch,_hideText,fgLbl,_fgWell,bgLbl,_bgWell,selLbl,_selection]) [dv addSubview:v];

    // ── Behaviour group ──────────────────────────────────────────────────────
    NSBox *gBeh = box(@"Behaviour");
    NSView *bv = gBeh.contentView;
    _useBookmark = chk(@"Use bookmarks in text");
    _autoUpdate  = chk(@"Auto update on modify");
    _syncScroll  = chk(@"Synchronize view scrolling");
    _dblClick    = chk(@"Dbl-Click jumps to EditView");
    NSTextField *enterLbl = lbl(@"Action on Enter");
    _onEnter = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_onEnter addItemsWithTitles:@[@"just search", @"update line", @"add line"]];
    _onEnter.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *cfgLbl = lbl(@"Recently used config files");
    _numCfg = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_numCfg addItemsWithTitles:@[@"0",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8"]];
    _numCfg.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *ctxLbl = lbl(@"Editor context menu");
    NSButton *ctxBtn = [NSButton buttonWithTitle:@"add command" target:self action:@selector(onAddContext:)];
    ctxBtn.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSView *v in @[_useBookmark,_autoUpdate,_syncScroll,_dblClick,enterLbl,_onEnter,cfgLbl,_numCfg,ctxLbl,ctxBtn]) [bv addSubview:v];

    // ── Result Window Font group ─────────────────────────────────────────────
    NSBox *gFont = box(@"Result Window Font");
    NSView *fv = gFont.contentView;
    NSTextField *nameLbl = lbl(@"Name");
    _fontName = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_fontName addItemWithTitle:@""];
    [_fontName addItemsWithTitles:[[NSFontManager sharedFontManager].availableFontFamilies
                                   sortedArrayUsingSelector:@selector(compare:)]];
    _fontName.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *sizeLbl = lbl(@"Size");
    _fontSize = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_fontSize addItemsWithTitles:@[@"6",@"7",@"8",@"9",@"10",@"11",@"12",@"14",@"16",@"18",@"20"]];
    _fontSize.translatesAutoresizingMaskIntoConstraints = NO;
    _showLineNo = chk(@"Show line numbers in result");
    _wordWrap   = chk(@"Word wrap mode in result");
    for (NSView *v in @[nameLbl,_fontName,sizeLbl,_fontSize,_showLineNo,_wordWrap]) [fv addSubview:v];

    // ── OK / Cancel ──────────────────────────────────────────────────────────
    NSButton *ok = [NSButton buttonWithTitle:@"OK" target:self action:@selector(onOK:)];
    ok.keyEquivalent = @"\r"; ok.translatesAutoresizingMaskIntoConstraints = NO;
    NSButton *cancel = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(onCancel:)];
    cancel.keyEquivalent = @"\033"; cancel.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSView *v in @[gDef, gBeh, gFont, ok, cancel]) [c addSubview:v];

    // Layout: two columns of groups on top, font group bottom-left, buttons bottom-right.
    [NSLayoutConstraint activateConstraints:@[
        [gDef.topAnchor constraintEqualToAnchor:c.topAnchor constant:12],
        [gDef.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:12],
        [gDef.widthAnchor constraintEqualToConstant:255],
        [gDef.heightAnchor constraintEqualToConstant:250],

        [gBeh.topAnchor constraintEqualToAnchor:gDef.topAnchor],
        [gBeh.leadingAnchor constraintEqualToAnchor:gDef.trailingAnchor constant:12],
        [gBeh.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-12],
        [gBeh.heightAnchor constraintEqualToConstant:230],

        [gFont.topAnchor constraintEqualToAnchor:gDef.bottomAnchor constant:12],
        [gFont.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:12],
        [gFont.widthAnchor constraintEqualToConstant:255],
        [gFont.heightAnchor constraintEqualToConstant:130],

        [cancel.bottomAnchor constraintEqualToAnchor:c.bottomAnchor constant:-12],
        [ok.bottomAnchor constraintEqualToAnchor:c.bottomAnchor constant:-12],
        [ok.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-12],
        [cancel.trailingAnchor constraintEqualToAnchor:ok.leadingAnchor constant:-10],
        [ok.widthAnchor constraintEqualToConstant:80],
        [cancel.widthAnchor constraintEqualToConstant:80],
    ]];
    [self layoutGroup:dv rows:@[ @[typeLbl,_searchType], @[_matchCase], @[_wholeWord], @[_doSearch],
        @[_hideText], @[fgLbl,_fgWell], @[bgLbl,_bgWell], @[selLbl,_selection] ]];
    [self layoutGroup:bv rows:@[ @[_useBookmark], @[_autoUpdate], @[_syncScroll], @[_dblClick],
        @[enterLbl,_onEnter], @[cfgLbl,_numCfg], @[ctxLbl,ctxBtn] ]];
    [self layoutGroup:fv rows:@[ @[nameLbl,_fontName], @[sizeLbl,_fontSize], @[_showLineNo], @[_wordWrap] ]];
}

// Simple vertical row layout inside a group's content view.
- (void)layoutGroup:(NSView *)g rows:(NSArray<NSArray<NSView *> *> *)rows {
    NSView *prev = nil;
    for (NSArray<NSView *> *row in rows) {
        NSView *first = row.firstObject;
        [g addConstraint:[NSLayoutConstraint constraintWithItem:first attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:g attribute:NSLayoutAttributeLeading multiplier:1 constant:10]];
        if (prev) {
            [g addConstraint:[NSLayoutConstraint constraintWithItem:first attribute:NSLayoutAttributeTop
                relatedBy:NSLayoutRelationEqual toItem:prev attribute:NSLayoutAttributeBottom multiplier:1 constant:8]];
        } else {
            [g addConstraint:[NSLayoutConstraint constraintWithItem:first attribute:NSLayoutAttributeTop
                relatedBy:NSLayoutRelationEqual toItem:g attribute:NSLayoutAttributeTop multiplier:1 constant:6]];
        }
        if (row.count > 1) {
            NSView *second = row[1];
            [g addConstraint:[NSLayoutConstraint constraintWithItem:second attribute:NSLayoutAttributeLeading
                relatedBy:NSLayoutRelationEqual toItem:first attribute:NSLayoutAttributeTrailing multiplier:1 constant:8]];
            [g addConstraint:[NSLayoutConstraint constraintWithItem:second attribute:NSLayoutAttributeCenterY
                relatedBy:NSLayoutRelationEqual toItem:first attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        }
        prev = first;
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
