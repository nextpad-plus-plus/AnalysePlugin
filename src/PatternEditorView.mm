// PatternEditorView.mm — macOS port of the Windows FindDlg pattern-list editor.
//
// Layout mirrors IDD_FIND_DLG_CONF (Image #1): a top edit area (search text,
// type, Case/Whole-word, Order#, Group, Comment, Do-Search/Hide-Text, FG/BG
// colour wells, Selection-On) above an 11-button grid, above the pattern table
// (13 columns, per-row coloured from each pattern's fg/bg).

#import "PatternEditorView.h"
#import "AnalyseController.h"
#include "Scintilla.h"
#include "tclColor.h"
#include <vector>

// ── COLORREF (0x00BBGGRR) ↔ NSColor ─────────────────────────────────────────
static NSColor *nsColorFromRef(COLORREF c) {
    CGFloat r = (c & 0xFF) / 255.0;
    CGFloat g = ((c >> 8) & 0xFF) / 255.0;
    CGFloat b = ((c >> 16) & 0xFF) / 255.0;
    return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
}
static COLORREF refFromNSColor(NSColor *col) {
    NSColor *c = [col colorUsingColorSpace:NSColorSpace.genericRGBColorSpace] ?: col;
    int r = (int)lround(c.redComponent * 255.0);
    int g = (int)lround(c.greenComponent * 255.0);
    int b = (int)lround(c.blueComponent * 255.0);
    return RGB(r, g, b);
}

// Column identifiers, in display order (matches tclTableview, RESULT_COLORING on).
static NSString *const kColActive  = @"Active";
static NSString *const kColOrder   = @"Order";
static NSString *const kColSearch  = @"Search";
static NSString *const kColGroup   = @"Group";
static NSString *const kColColor   = @"Color";
static NSString *const kColBgCol   = @"BgCol";
static NSString *const kColType    = @"Type";
static NSString *const kColCase    = @"Case";
static NSString *const kColWord    = @"Word";
static NSString *const kColSelect  = @"Select";
static NSString *const kColHide    = @"Hide";
static NSString *const kColComment = @"Comment";

@interface PatternEditorView () <NSTableViewDataSource, NSTableViewDelegate, NSComboBoxDelegate>
@end

@implementation PatternEditorView {
    __weak AnalyseController *_controller;
    tclResultList _resultList;
    tclPattern    _defaultPattern;

    // Edit controls
    NSComboBox    *_searchText;
    NSPopUpButton *_searchType;
    NSButton      *_caseChk;
    NSButton      *_wholeWordChk;
    NSTextField   *_orderNum;
    NSComboBox    *_group;
    NSComboBox    *_comment;
    NSButton      *_doSearchChk;
    NSButton      *_hideChk;
    NSColorWell   *_fgWell;
    NSColorWell   *_bgWell;
    NSPopUpButton *_selection;

    NSTableView   *_table;

    BOOL _suppressSelectionSync;
}

- (instancetype)initWithController:(AnalyseController *)controller {
    if ((self = [super initWithFrame:NSMakeRect(0, 0, 320, 640)])) {
        _controller = controller;
        [self buildUI];
        [self reloadTable];
    }
    return self;
}

- (tclResultList &)resultListRef { return _resultList; }
- (const tclPattern &)defaultPattern { return _defaultPattern; }

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - UI construction

static NSTextField *mkLabel(NSString *s) {
    NSTextField *l = [NSTextField labelWithString:s];
    l.font = [NSFont systemFontOfSize:11];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    return l;
}

- (NSButton *)mkCheck:(NSString *)title action:(SEL)sel {
    NSButton *b = [NSButton checkboxWithTitle:title target:self action:sel];
    b.font = [NSFont systemFontOfSize:11];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

- (NSButton *)mkButton:(NSString *)title action:(SEL)sel {
    NSButton *b = [NSButton buttonWithTitle:title target:self action:sel];
    b.font = [NSFont systemFontOfSize:11];
    b.bezelStyle = NSBezelStyleRounded;
    b.controlSize = NSControlSizeSmall;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

- (void)buildUI {
    // ── edit controls ────────────────────────────────────────────────────────
    _searchText = [[NSComboBox alloc] initWithFrame:NSZeroRect];
    _searchText.editable = YES;
    _searchText.completes = NO;
    _searchText.font = [NSFont systemFontOfSize:11];
    _searchText.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *typeLbl = mkLabel(@"Search");
    _searchType = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_searchType addItemsWithTitles:@[@"normal", @"escaped", @"regex", @"rgx_multiline"]];
    _searchType.font = [NSFont systemFontOfSize:11];
    _searchType.controlSize = NSControlSizeSmall;
    _searchType.translatesAutoresizingMaskIntoConstraints = NO;

    _caseChk = [self mkCheck:@"Case" action:nil];
    _wholeWordChk = [self mkCheck:@"Whole word" action:nil];

    NSTextField *orderLbl = mkLabel(@"Order#");
    _orderNum = [[NSTextField alloc] initWithFrame:NSZeroRect];
    _orderNum.font = [NSFont systemFontOfSize:11];
    _orderNum.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *groupLbl = mkLabel(@"Group");
    _group = [[NSComboBox alloc] initWithFrame:NSZeroRect];
    _group.editable = YES; _group.completes = NO;
    _group.font = [NSFont systemFontOfSize:11];
    _group.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *commentLbl = mkLabel(@"Comment");
    _comment = [[NSComboBox alloc] initWithFrame:NSZeroRect];
    _comment.editable = YES; _comment.completes = NO;
    _comment.font = [NSFont systemFontOfSize:11];
    _comment.translatesAutoresizingMaskIntoConstraints = NO;

    _doSearchChk = [self mkCheck:@"Do Search" action:nil];
    _doSearchChk.state = NSControlStateValueOn;
    _hideChk = [self mkCheck:@"Hide Text" action:nil];

    NSTextField *fgLbl = mkLabel(@"Colour FG");
    _fgWell = [[NSColorWell alloc] initWithFrame:NSZeroRect];
    _fgWell.translatesAutoresizingMaskIntoConstraints = NO;
    _fgWell.color = nsColorFromRef(tclColor::getColRgb(tclColor::black));

    NSTextField *bgLbl = mkLabel(@"Colour BG");
    _bgWell = [[NSColorWell alloc] initWithFrame:NSZeroRect];
    _bgWell.translatesAutoresizingMaskIntoConstraints = NO;
    _bgWell.color = nsColorFromRef(tclColor::getColRgb(tclColor::white));

    NSTextField *selLbl = mkLabel(@"Selection On");
    _selection = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_selection addItemsWithTitles:@[@"text", @"line"]];
    [_selection selectItemWithTitle:@"line"];
    _selection.font = [NSFont systemFontOfSize:11];
    _selection.controlSize = NSControlSizeSmall;
    _selection.translatesAutoresizingMaskIntoConstraints = NO;

    // ── button grid (3 columns × 3 rows + extra) ──────────────────────────────
    NSButton *add    = [self mkButton:@"Add"    action:@selector(onAdd:)];
    NSButton *up     = [self mkButton:@"^"      action:@selector(onUp:)];
    NSButton *down   = [self mkButton:@"v"      action:@selector(onDown:)];
    NSButton *load   = [self mkButton:@"Load"   action:@selector(onLoad:)];
    NSButton *update = [self mkButton:@"Update" action:@selector(onUpdate:)];
    NSButton *order  = [self mkButton:@"Order"  action:@selector(onOrder:)];
    NSButton *save   = [self mkButton:@"Save"   action:@selector(onSave:)];
    NSButton *del    = [self mkButton:@"Delete" action:@selector(onDelete:)];
    NSButton *clear  = [self mkButton:@"Clear"  action:@selector(onClear:)];
    NSButton *search = [self mkButton:@"Search" action:@selector(onSearch:)];
    search.keyEquivalent = @"\r";

    // ── table ──────────────────────────────────────────────────────────────
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = YES;
    scroll.autohidesScrollers = YES;   // overlay scrollers — don't reserve space
    scroll.borderType = NSBezelBorder;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;

    _table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    _table.usesAlternatingRowBackgroundColors = NO;
    _table.allowsColumnReordering = YES;
    _table.allowsColumnResizing = YES;
    _table.allowsMultipleSelection = NO;
    _table.rowHeight = 16;
    _table.dataSource = self;
    _table.delegate = self;
    _table.columnAutoresizingStyle = NSTableViewNoColumnAutoresizing;

    struct { NSString *ident; NSString *title; CGFloat w; } cols[] = {
        {kColActive,  @"Active",  44}, {kColOrder, @"Order", 44}, {kColSearch, @"Search", 120},
        {kColGroup,   @"Group",   60}, {kColColor, @"Color", 60}, {kColBgCol,  @"BgCol",  60},
        {kColType,    @"Type",    70}, {kColCase,  @"Case",  40}, {kColWord,   @"Word",   44},
        {kColSelect,  @"Select",  50}, {kColHide,  @"Hide",  40}, {kColComment,@"Comment",160},
    };
    for (auto &c : cols) {
        NSTableColumn *tc = [[NSTableColumn alloc] initWithIdentifier:c.ident];
        tc.title = c.title;
        tc.width = c.w;
        tc.headerCell.font = [NSFont systemFontOfSize:11];
        [_table addTableColumn:tc];
    }
    scroll.documentView = _table;

    // ── assemble with Auto Layout ────────────────────────────────────────────
    NSArray *allViews = @[_searchText, typeLbl, _searchType, _caseChk, _wholeWordChk,
                          orderLbl, _orderNum, groupLbl, _group, commentLbl, _comment,
                          _doSearchChk, _hideChk, fgLbl, _fgWell, bgLbl, _bgWell,
                          selLbl, _selection, add, up, down, load, update, order, save,
                          del, clear, search, scroll];
    for (NSView *v in allViews) [self addSubview:v];

    CGFloat M = 6;     // left margin
    id sa = self.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        // search text — full width, top
        [_searchText.topAnchor constraintEqualToAnchor:[sa topAnchor] constant:6],
        [_searchText.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [_searchText.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-M],

        // Search type row
        [typeLbl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [typeLbl.centerYAnchor constraintEqualToAnchor:_searchType.centerYAnchor],
        [_searchType.topAnchor constraintEqualToAnchor:_searchText.bottomAnchor constant:6],
        [_searchType.leadingAnchor constraintEqualToAnchor:typeLbl.trailingAnchor constant:6],
        [_searchType.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-M],

        // Case / Whole word
        [_caseChk.topAnchor constraintEqualToAnchor:_searchType.bottomAnchor constant:6],
        [_caseChk.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [_wholeWordChk.centerYAnchor constraintEqualToAnchor:_caseChk.centerYAnchor],
        [_wholeWordChk.leadingAnchor constraintEqualToAnchor:_caseChk.trailingAnchor constant:10],

        // Order#
        [orderLbl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [orderLbl.centerYAnchor constraintEqualToAnchor:_orderNum.centerYAnchor],
        [_orderNum.topAnchor constraintEqualToAnchor:_caseChk.bottomAnchor constant:6],
        [_orderNum.leadingAnchor constraintEqualToAnchor:orderLbl.trailingAnchor constant:6],
        [_orderNum.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-M],

        // Group
        [groupLbl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [groupLbl.centerYAnchor constraintEqualToAnchor:_group.centerYAnchor],
        [_group.topAnchor constraintEqualToAnchor:_orderNum.bottomAnchor constant:6],
        [_group.leadingAnchor constraintEqualToAnchor:groupLbl.trailingAnchor constant:6],
        [_group.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-M],

        // Comment
        [commentLbl.topAnchor constraintEqualToAnchor:_group.bottomAnchor constant:6],
        [commentLbl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [_comment.topAnchor constraintEqualToAnchor:commentLbl.bottomAnchor constant:2],
        [_comment.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [_comment.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-M],

        // Do Search / Hide Text
        [_doSearchChk.topAnchor constraintEqualToAnchor:_comment.bottomAnchor constant:6],
        [_doSearchChk.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [_hideChk.centerYAnchor constraintEqualToAnchor:_doSearchChk.centerYAnchor],
        [_hideChk.leadingAnchor constraintEqualToAnchor:_doSearchChk.trailingAnchor constant:10],

        // FG colour + Selection On (two columns)
        [fgLbl.topAnchor constraintEqualToAnchor:_doSearchChk.bottomAnchor constant:8],
        [fgLbl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [_fgWell.centerYAnchor constraintEqualToAnchor:fgLbl.centerYAnchor],
        [_fgWell.leadingAnchor constraintEqualToAnchor:fgLbl.trailingAnchor constant:6],
        [_fgWell.widthAnchor constraintEqualToConstant:22],
        [_fgWell.heightAnchor constraintEqualToConstant:16],

        [bgLbl.topAnchor constraintEqualToAnchor:fgLbl.bottomAnchor constant:8],
        [bgLbl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [_bgWell.centerYAnchor constraintEqualToAnchor:bgLbl.centerYAnchor],
        [_bgWell.leadingAnchor constraintEqualToAnchor:bgLbl.trailingAnchor constant:6],
        [_bgWell.widthAnchor constraintEqualToConstant:22],
        [_bgWell.heightAnchor constraintEqualToConstant:16],

        [selLbl.topAnchor constraintEqualToAnchor:_hideChk.bottomAnchor constant:8],
        [selLbl.trailingAnchor constraintEqualToAnchor:_selection.leadingAnchor constant:-6],
        [selLbl.centerYAnchor constraintEqualToAnchor:_selection.centerYAnchor],
        [_selection.topAnchor constraintEqualToAnchor:fgLbl.bottomAnchor constant:2],
        [_selection.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-M],
        [_selection.widthAnchor constraintEqualToConstant:90],

        // button grid
        [add.topAnchor constraintEqualToAnchor:_bgWell.bottomAnchor constant:10],
        [add.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [add.widthAnchor constraintEqualToConstant:60],
        [up.centerYAnchor constraintEqualToAnchor:add.centerYAnchor],
        [up.leadingAnchor constraintEqualToAnchor:add.trailingAnchor constant:4],
        [up.widthAnchor constraintEqualToConstant:28],
        [down.centerYAnchor constraintEqualToAnchor:add.centerYAnchor],
        [down.leadingAnchor constraintEqualToAnchor:up.trailingAnchor constant:4],
        [down.widthAnchor constraintEqualToConstant:28],
        [load.centerYAnchor constraintEqualToAnchor:add.centerYAnchor],
        [load.leadingAnchor constraintEqualToAnchor:down.trailingAnchor constant:4],
        [load.widthAnchor constraintEqualToConstant:60],

        [update.topAnchor constraintEqualToAnchor:add.bottomAnchor constant:4],
        [update.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [update.widthAnchor constraintEqualToConstant:60],
        [order.centerYAnchor constraintEqualToAnchor:update.centerYAnchor],
        [order.leadingAnchor constraintEqualToAnchor:update.trailingAnchor constant:4],
        [order.widthAnchor constraintEqualToConstant:60],
        [save.centerYAnchor constraintEqualToAnchor:update.centerYAnchor],
        [save.leadingAnchor constraintEqualToAnchor:order.trailingAnchor constant:4],
        [save.widthAnchor constraintEqualToConstant:60],

        [del.topAnchor constraintEqualToAnchor:update.bottomAnchor constant:4],
        [del.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:M],
        [del.widthAnchor constraintEqualToConstant:60],
        [clear.centerYAnchor constraintEqualToAnchor:del.centerYAnchor],
        [clear.leadingAnchor constraintEqualToAnchor:del.trailingAnchor constant:4],
        [clear.widthAnchor constraintEqualToConstant:60],
        [search.centerYAnchor constraintEqualToAnchor:del.centerYAnchor],
        [search.leadingAnchor constraintEqualToAnchor:clear.trailingAnchor constant:4],
        [search.widthAnchor constraintEqualToConstant:60],

        // table fills the rest
        [scroll.topAnchor constraintEqualToAnchor:del.bottomAnchor constant:8],
        [scroll.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0],
        [scroll.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:0],
        [scroll.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:0],
    ]];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - dialog ⇄ pattern sync

// Build a tclPattern from the current edit controls.
- (tclPattern)patternFromControls {
    tclPattern p = _defaultPattern;
    p.setSearchText(_searchText.stringValue.UTF8String ?: "");
    p.setSearchType((int)_searchType.indexOfSelectedItem);
    p.setMatchCase(_caseChk.state == NSControlStateValueOn);
    p.setWholeWord(_wholeWordChk.state == NSControlStateValueOn);
    p.setOrderNumStr(_orderNum.stringValue.UTF8String ?: "");
    p.setGroup(_group.stringValue.UTF8String ?: "");
    p.setComment(_comment.stringValue.UTF8String ?: "");
    p.setDoSearch(_doSearchChk.state == NSControlStateValueOn);
    p.setHideText(_hideChk.state == NSControlStateValueOn);
    p.setColor(refFromNSColor(_fgWell.color));
    p.setBgColor(refFromNSColor(_bgWell.color));
    p.setSelectionType((int)_selection.indexOfSelectedItem);  // 0=text,1=line
    return p;
}

// Populate the edit controls from a pattern.
- (void)controlsFromPattern:(const tclPattern &)p {
    _searchText.stringValue = @(p.getSearchText().c_str());
    [_searchType selectItemAtIndex:(NSInteger)p.getSearchType()];
    _caseChk.state = p.getIsMatchCase() ? NSControlStateValueOn : NSControlStateValueOff;
    _wholeWordChk.state = p.getIsWholeWord() ? NSControlStateValueOn : NSControlStateValueOff;
    _orderNum.stringValue = @(p.getOrderNumStr().c_str());
    _group.stringValue = @(p.getGroup().c_str());
    _comment.stringValue = @(p.getComment().c_str());
    _doSearchChk.state = p.getDoSearch() ? NSControlStateValueOn : NSControlStateValueOff;
    _hideChk.state = p.getIsHideText() ? NSControlStateValueOn : NSControlStateValueOff;
    _fgWell.color = nsColorFromRef(p.getColorNum());
    _bgWell.color = nsColorFromRef(p.getBgColorNum());
    [_selection selectItemAtIndex:(NSInteger)p.getSelectionType()];
}

- (tPatId)selectedPatId {
    NSInteger row = _table.selectedRow;
    if (row < 0 || row >= (NSInteger)_resultList.size()) return -1;
    return _resultList.getPatternId((unsigned)row);
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - buttons

- (void)onAdd:(id)sender {
    tclPattern p = [self patternFromControls];
    tPatId sel = [self selectedPatId];
    if (sel >= 0) _resultList.insertAfter(sel, p);
    else          _resultList.push_back(p);
    [self reloadTable];
}

- (void)onUpdate:(id)sender {
    tPatId sel = [self selectedPatId];
    tclPattern p = [self patternFromControls];
    if (sel < 0) { _resultList.push_back(p); }
    else         { _resultList.setPattern(sel, p); }
    [self reloadTable];
}

- (void)onDelete:(id)sender {
    tPatId sel = [self selectedPatId];
    if (sel < 0) return;
    _resultList.remove(sel);
    [self reloadTable];
}

- (void)onUp:(id)sender { [self moveSelectedBy:-1]; }
- (void)onDown:(id)sender { [self moveSelectedBy:+1]; }

- (void)moveSelectedBy:(int)delta {
    NSInteger row = _table.selectedRow;
    if (row < 0) return;
    NSInteger target = row + delta;
    if (target < 0 || target >= (NSInteger)_resultList.size()) return;
    tPatId sel = _resultList.getPatternId((unsigned)row);
    tclPattern p = _resultList.getPattern(sel);
    tclResult savedResult = _resultList.refResult(sel);
    _resultList.remove(sel);
    // Re-insert at the target index by anchoring on the neighbour pattern.
    tPatId newId;
    if (target == 0) {
        newId = _resultList.insert(_resultList.getPatternId(0), p);
    } else if (target >= (NSInteger)_resultList.size()) {
        newId = _resultList.push_back(p);
    } else {
        // insert before the pattern currently at `target`
        newId = _resultList.insert(_resultList.getPatternId((unsigned)target), p);
    }
    _resultList.refResult(newId) = savedResult;
    [self reloadTable];
    NSInteger newRow = (NSInteger)_resultList.getPatternIndex(newId);
    if (newRow >= 0) [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
}

- (void)onClear:(id)sender {
    _resultList.clear();
    [self reloadTable];
    [_controller doSearch];   // clears the result window too
}

- (void)onSearch:(id)sender { [self runSearch]; }
- (void)onOrder:(id)sender  { /* sort submenu — next pass */ }
- (void)onLoad:(id)sender   { /* config load — next pass */ }
- (void)onSave:(id)sender   { /* config save — next pass */ }

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - public commands

- (void)addSelectionAsPatterns {
    intptr_t len = [_controller sci:SCI_GETSELTEXT wParam:0 lParam:0];
    if (len <= 1) return;
    std::string buf;
    buf.resize((size_t)len + 1);
    [_controller sci:SCI_GETSELTEXT wParam:0 lParam:(intptr_t)&buf[0]];
    buf.resize(strlen(buf.c_str()));

    NSString *sel = [NSString stringWithUTF8String:buf.c_str()] ?: @"";
    NSArray<NSString *> *lines = [sel componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet newlineCharacterSet]];
    int colorIdx = 0;
    int nColors = tclColor::getDefColorListSize();
    for (NSString *raw in lines) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (line.length == 0) continue;
        tclPattern p = _defaultPattern;
        p.setSearchText(line.UTF8String);
        p.setColor(tclColor::getDefColorNum(colorIdx % nColors));
        ++colorIdx;
        _resultList.push_back(p);
    }
    [self reloadTable];
    [self runSearch];
}

- (void)runSearch {
    [_controller doSearch];
    [self reloadTable];   // refresh Hits column etc.
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - table

- (void)reloadTable {
    [_table reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)_resultList.size();
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)col
                  row:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)_resultList.size()) return nil;
    tPatId pid = _resultList.getPatternId((unsigned)row);
    const tclPattern &p = _resultList.getPattern(pid);

    NSString *ident = col.identifier;
    NSString *text = @"";
    if      ([ident isEqual:kColActive])  text = p.getDoSearch() ? @"X" : @"";
    else if ([ident isEqual:kColOrder])   text = @(p.getOrderNumStr().c_str());
    else if ([ident isEqual:kColSearch])  text = @(p.getSearchText().c_str());
    else if ([ident isEqual:kColGroup])   text = @(p.getGroup().c_str());
    else if ([ident isEqual:kColColor])   text = @(p.getColorStr().c_str());
    else if ([ident isEqual:kColBgCol])   text = @(p.getBgColorStr().c_str());
    else if ([ident isEqual:kColType])    text = @(p.getSearchTypeStr().c_str());
    else if ([ident isEqual:kColCase])    text = p.getIsMatchCase() ? @"X" : @"";
    else if ([ident isEqual:kColWord])    text = p.getIsWholeWord() ? @"X" : @"";
    else if ([ident isEqual:kColSelect])  text = @(p.getSelectionTypeStr().c_str());
    else if ([ident isEqual:kColHide])    text = p.getIsHideText() ? @"X" : @"";
    else if ([ident isEqual:kColComment]) text = @(p.getComment().c_str());

    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"cell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = @"cell";
        NSTextField *tf = [NSTextField labelWithString:@""];
        tf.font = [NSFont systemFontOfSize:11];
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        tf.drawsBackground = YES;
        [cell addSubview:tf];
        cell.textField = tf;
        [NSLayoutConstraint activateConstraints:@[
            [tf.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:2],
            [tf.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-2],
            [tf.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        ]];
    }
    cell.textField.stringValue = text ?: @"";
    // Per-row coloring from the pattern's fg/bg (mirrors NM_CUSTOMDRAW).
    cell.textField.textColor = nsColorFromRef(p.getColorNum());
    cell.textField.backgroundColor = nsColorFromRef(p.getBgColorNum());
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (_suppressSelectionSync) return;
    tPatId sel = [self selectedPatId];
    if (sel < 0) return;
    [self controlsFromPattern:_resultList.getPattern(sel)];
}

@end
