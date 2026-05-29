// ResultPanelView.mm — macOS port of tclFindResultDlg. See header.

#import "ResultPanelView.h"
#import "AnalyseController.h"
#import "ScintillaView.h"
#include "Scintilla.h"

// Result-line head decorations (verbatim from tclFindResultDlg.cpp).
#define FNDRESDLG_LINE_HEAD   ""
#define FNDRESDLG_LINE_COLON  ": "
#define FNDRESDLG_LINE_HYPHEN "| "
#define FNDRESDLG_DEFAULT_STYLE STYLE_DEFAULT   // 32

// Style mask: 8 bits → styles 0..255. We skip Scintilla's reserved 32..39.
#define MY_STYLE_MASK  0xff
#define MY_STYLE_COUNT (MY_STYLE_MASK - 8)      // 247 usable pattern styles

// Standard Notepad++ margin indices (from the host ScintillaEditView).
#define SC_MARGE_LINENUMBER 0
#define SC_MARGE_SYMBOL     1
#define SC_MARGE_FOLDER     2

@interface ResultPanelView () <ScintillaNotificationProtocol>
@end

@implementation ResultPanelView {
    __weak AnalyseController *_controller;
    ScintillaView *_sci;                 // host class, resolved at runtime

    // C++ model (mirrors tclFindResultDlg's members).
    tclFindResultDoc  _findResults;
    tclPatternList    _patStyleList;

    int     _miLineNumColSize;
    int     _miLineHeadSize;
    size_t  _lineCounter;
    tiLine  _markedLine;
    BOOL    _fromMainWindow;             // main scroll drives result
    BOOL    _fromFindResult;             // result scroll/jump drives main
    NSString *_searchFileName;
    int     _styleIdTab[MY_STYLE_COUNT]; // transStyleIdTab
}

- (instancetype)initWithController:(AnalyseController *)controller {
    if ((self = [super initWithFrame:NSMakeRect(0, 0, 900, 240)])) {
        _controller = controller;
        _markedLine = -1;
        _miLineNumColSize = 0;
        _miLineHeadSize = 0;
        _lineCounter = 0;
        // Defaults mirror the Windows Options dialog (Image #2).
        _useBookmark = YES;
        _displayComment = NO;
        _lineNumbersInResult = YES;
        _wrapMode = NO;
        _syncScroll = YES;
        _dblClickJumpsToEditView = YES;
        _resultFontName = @"";
        _resultFontSize = 8;
        [self buildStyleIdTable];
        [self buildScintilla];
    }
    return self;
}

// transStyleIdTab: 1..31 then 40..255 (skip Scintilla-reserved 32..39).
- (void)buildStyleIdTable {
    int v = 0;
    for (int i = 0; i < MY_STYLE_COUNT; ++i) {
        v = (i < 31) ? (i + 1) : (40 + (i - 31));
        _styleIdTab[i] = v;
    }
}

- (int)transStyleId:(unsigned)idx {
    if (idx < (unsigned)MY_STYLE_COUNT) return _styleIdTab[idx];
    return STYLE_DEFAULT;
}

- (void)buildScintilla {
    Class scintillaClass = NSClassFromString(@"ScintillaView");
    if (!scintillaClass) {
        NSLog(@"[AnalysePlugin] ScintillaView class unavailable in host process");
        return;
    }
    _sci = [[scintillaClass alloc] initWithFrame:self.bounds];
    _sci.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self addSubview:_sci];
    _sci.delegate = self;
    _sci.scrollView.autohidesScrollers = YES;   // overlay scrollers — don't reserve space

    // Container styling — we colour the buffer ourselves on SCN_STYLENEEDED.
    [self sci:SCI_SETILEXER wParam:0 lParam:(intptr_t)0];   // null lexer
    [self sci:SCI_SETCODEPAGE wParam:SC_CP_UTF8 lParam:0];
    [self sci:SCI_SETEOLMODE wParam:SC_EOL_CRLF lParam:0];  // result lines end CRLF
    [self sci:SCI_USEPOPUP wParam:0 lParam:0];              // our own context menu
    [self sci:SCI_SETSCROLLWIDTHTRACKING wParam:1 lParam:0];
    [self sci:SCI_SETSCROLLWIDTH wParam:1 lParam:0];

    // Margins: line-number gutter on, symbol/folder off.
    [self sci:SCI_SETMARGINWIDTHN wParam:SC_MARGE_SYMBOL lParam:0];
    [self sci:SCI_SETMARGINWIDTHN wParam:SC_MARGE_FOLDER lParam:0];
    [self applyWrapMode];
    [self sci:SCI_SETREADONLY wParam:1 lParam:0];
}

- (intptr_t)sci:(uint32_t)msg wParam:(uintptr_t)wParam lParam:(intptr_t)lParam {
    if (!_sci) return 0;
    return [_sci message:msg wParam:wParam lParam:lParam];
}

- (void)setReadOnly:(BOOL)ro { [self sci:SCI_SETREADONLY wParam:(ro ? 1 : 0) lParam:0]; }

// ── line-number column sizing ──────────────────────────────────────────────
- (int)lineNumColSize { return _miLineNumColSize; }
- (void)setLineNumColSize:(int)size {
    _miLineNumColSize = size;
    _miLineHeadSize = _miLineNumColSize + (int)(strlen(FNDRESDLG_LINE_COLON) + strlen(FNDRESDLG_LINE_HEAD));
}

- (tiLine)resultSize { return _findResults.size(); }
- (void)reserveLines:(unsigned)count { _findResults.reserve(count); }
- (BOOL)lineAvail:(tiLine)foundLine { return _findResults.getLineAvail(foundLine) ? YES : NO; }
- (void)setSearchFileName:(NSString *)name { _searchFileName = [name copy]; }

- (tiLine)insertPosInfo:(tPatId)patternId line:(tiLine)foundLine pos:(tclPosInfo)pos {
    return _findResults.insertPosInfo(patternId, foundLine, pos);
}

// ── marked line in the MAIN editor (jump target) ───────────────────────────
- (void)setMarkedLineInMain:(tiLine)line {
    _markedLine = line;
    if (line != -1) {
        _fromFindResult = YES;
        [_controller sci:SCI_GOTOLINE wParam:(uintptr_t)line lParam:0];
    }
}

// ── clear ───────────────────────────────────────────────────────────────────
- (void)clearResults:(BOOL)initial {
    [self setMarkedLineInMain:-1];
    _findResults.clear();
    if (_useBookmark && !initial)
        [_controller sci:SCI_MARKERDELETEALL wParam:(uintptr_t)[_controller bookmarkId] lParam:0];
    if (_sci) {
        [self setReadOnly:NO];
        [self sci:SCI_CLEARALL wParam:0 lParam:0];
        [self setReadOnly:YES];
    }
    _lineCounter = 0;
}

// ── insert / update one result line (port of setLineText) ───────────────────
- (void)setLineText:(tiLine)foundLine
               text:(const std::string &)text
            comment:(const std::string &)comment
       commentWidth:(unsigned)commentWidth {
    bool bNewLine = _findResults.setLineText(foundLine, text);
    tiLine resLine = _findResults.getLineNoAtRes(foundLine);
    tiLine startPos = [self sci:SCI_POSITIONFROMLINE wParam:(uintptr_t)resLine lParam:0];
    if (startPos == -1) return;

    [self setMarkedLineInMain:-1];
    [self setReadOnly:NO];

    std::string s = FNDRESDLG_LINE_HEAD;
    char conv[24];
    if (_lineNumbersInResult) {
        size_t nlen = strlen(_i64toa((long long)(foundLine + 1), conv, 10));
        if ((size_t)_miLineNumColSize > nlen) s.append((size_t)_miLineNumColSize - nlen, ' ');
        s.append(conv);
        s.append(FNDRESDLG_LINE_COLON);
    }
    if (_displayComment) {
        s.append(comment);
        if (commentWidth > comment.length()) s.append(commentWidth - comment.length(), ' ');
        s.append(FNDRESDLG_LINE_HYPHEN);
    }
    s.append(text);

    if (bNewLine) {
        if (_useBookmark)
            [_controller sci:SCI_MARKERADD wParam:(uintptr_t)foundLine lParam:[_controller bookmarkId]];
        [self sci:SCI_INSERTTEXT wParam:(uintptr_t)startPos lParam:(intptr_t)s.c_str()];
        ++_lineCounter;
    } else {
        tiLine endPos = [self sci:SCI_GETLINEENDPOSITION wParam:(uintptr_t)resLine lParam:0];
        if (endPos + 2 <= [self sci:SCI_GETLENGTH wParam:0 lParam:0]) endPos += 2;
        [self sci:SCI_SETTARGETSTART wParam:(uintptr_t)startPos lParam:0];
        [self sci:SCI_SETTARGETEND wParam:(uintptr_t)endPos lParam:0];
        [self sci:SCI_REPLACETARGET wParam:(uintptr_t)-1 lParam:(intptr_t)s.c_str()];
    }
    [self setReadOnly:YES];
}

// ── remove result lines no longer referenced (port of removeUnusedResultLines)
- (void)removeUnusedResultLines:(tPatId)pattId
                            old:(const tclResult &)oldResult
                            new:(const tclResult &)newResult {
    for (int i = 0; i < (int)oldResult.size(); ++i) {
        tiLine thisLine = oldResult.getPosition(i).line;
        if (!_findResults.getLineAtMainAvail(thisLine)) continue;
        tclLinePosInfo &l = _findResults.refLineAtMain(thisLine);
        l.posInfos().erase(pattId);
        if (l.posInfos().size() != 0) continue;
        tiLine resultLine = _findResults.getLineNoAtRes(thisLine);
        if (resultLine >= 0) {
            if (_useBookmark)
                [_controller sci:SCI_MARKERDELETE wParam:(uintptr_t)thisLine lParam:[_controller bookmarkId]];
            tiLine startL = [self sci:SCI_POSITIONFROMLINE wParam:(uintptr_t)resultLine lParam:0];
            tiLine endL = [self sci:SCI_GETLINEENDPOSITION wParam:(uintptr_t)resultLine lParam:0];
            if (endL + 2 <= [self sci:SCI_GETLENGTH wParam:0 lParam:0]) endL += 2;
            if (endL > startL) {
                [self setReadOnly:NO];
                [self sci:SCI_SETTARGETSTART wParam:(uintptr_t)startL lParam:0];
                [self sci:SCI_SETTARGETEND wParam:(uintptr_t)endL lParam:0];
                [self sci:SCI_REPLACETARGET wParam:0 lParam:(intptr_t) ""];
                [self setReadOnly:YES];
            }
        }
        _findResults.erase(thisLine);
    }
    [self sci:SCI_SETSEL wParam:(uintptr_t)-1 lParam:0];
    [self sci:SCI_COLOURISE wParam:0 lParam:-1];
}

// ── pattern styles (port of setPatternStyles) ──────────────────────────────
- (void)setPatternStyles:(const tclPatternList &)list
          defaultPattern:(const tclPattern &)defPat {
    if (_findResults.size() == 0) _patStyleList.clear();

    bool bReStyle = false;
    for (tclPatternList::const_iterator it = list.begin(); it != list.end(); ++it) {
        tclPatternList::const_iterator iIntern = _patStyleList.find(it.getPatId());
        if (iIntern != _patStyleList.end()) {
            if (iIntern.getPattern().getSelectionType() != it.getPattern().getSelectionType())
                bReStyle = true;
        }
        _patStyleList.setPattern(it.getPatId(), it.getPattern());
    }

    // Default style.
    unsigned iDefPat = FNDRESDLG_DEFAULT_STYLE;
    tclPattern dp = defPat;
    [self sci:SCI_STYLESETVISIBLE   wParam:iDefPat lParam:!dp.getIsHideText()];
    [self sci:SCI_STYLESETBOLD      wParam:iDefPat lParam:dp.getIsBold()];
    [self sci:SCI_STYLESETITALIC    wParam:iDefPat lParam:dp.getIsItalic()];
    [self sci:SCI_STYLESETUNDERLINE wParam:iDefPat lParam:dp.getIsUnderlined()];
    [self sci:SCI_STYLESETFORE      wParam:iDefPat lParam:(intptr_t)dp.getColorNum()];
    [self sci:SCI_STYLESETBACK      wParam:iDefPat lParam:(intptr_t)dp.getBgColorNum()];
    [self sci:SCI_STYLESETEOLFILLED wParam:iDefPat lParam:(dp.getSelectionType() == tclPattern::line)];

    for (unsigned iPat = 0; iPat < _patStyleList.size(); ++iPat) {
        if (iPat >= (unsigned)MY_STYLE_COUNT) break;  // no more style slots
        const tclPattern &rPat = _patStyleList.getPattern(_patStyleList.getPatternId(iPat));
        int sid = [self transStyleId:iPat];
        [self sci:SCI_STYLESETVISIBLE   wParam:(uintptr_t)sid lParam:!rPat.getIsHideText()];
        [self sci:SCI_STYLESETBOLD      wParam:(uintptr_t)sid lParam:rPat.getIsBold()];
        [self sci:SCI_STYLESETITALIC    wParam:(uintptr_t)sid lParam:rPat.getIsItalic()];
        [self sci:SCI_STYLESETUNDERLINE wParam:(uintptr_t)sid lParam:rPat.getIsUnderlined()];
        [self sci:SCI_STYLESETFORE      wParam:(uintptr_t)sid lParam:(intptr_t)rPat.getColorNum()];
        [self sci:SCI_STYLESETBACK      wParam:(uintptr_t)sid lParam:(intptr_t)rPat.getBgColorNum()];
        [self sci:SCI_STYLESETEOLFILLED wParam:(uintptr_t)sid lParam:(rPat.getSelectionType() == tclPattern::line)];
    }
    [self applyResultFont];
    if (bReStyle) [self sci:SCI_COLOURISE wParam:0 lParam:-1];
}

- (void)setStyle:(tPatId)patternId begin:(tiLine)beginPos length:(tiLine)len {
    unsigned u = _patStyleList.getPatternIndex(patternId);
    int sid = [self transStyleId:u];
    [self sci:SCI_STARTSTYLING wParam:(uintptr_t)beginPos lParam:MY_STYLE_MASK];
    [self sci:SCI_SETSTYLING wParam:(uintptr_t)len lParam:sid];
}

- (void)setDefaultStyleBegin:(tiLine)beginPos length:(tiLine)len {
    [self sci:SCI_STARTSTYLING wParam:(uintptr_t)beginPos lParam:MY_STYLE_MASK];
    [self sci:SCI_SETSTYLING wParam:(uintptr_t)len lParam:FNDRESDLG_DEFAULT_STYLE];
}

// ── container styling (port of doStyle) ─────────────────────────────────────
- (void)doStyleFromResultLine:(tiLine)startResultLineNo
                   startNeeded:(tiLine)startStyleNeeded
                     endNeeded:(tiLine)endStyleNeeded {
    tiLine resultLineNum = startResultLineNo;
    tiLine styleBegin = startStyleNeeded;
    tiLine maxResultLines = [self sci:SCI_GETLINECOUNT wParam:0 lParam:0];
    tiLine endOfLine = [self sci:SCI_GETLINEENDPOSITION wParam:(uintptr_t)resultLineNum lParam:0]
                       + ((resultLineNum < maxResultLines) ? 2 : 0);
    do {
        if (resultLineNum < _findResults.size()) {
            const tlpLinePosInfo &rlpi = _findResults.getLineAtRes(resultLineNum);
            tiLine iLength = endOfLine - styleBegin;
            if (iLength < 0) { continue; }
            [self setDefaultStyleBegin:styleBegin length:iLength];
            int iThisLineHead = _lineNumbersInResult ? _miLineHeadSize : 0;
            if (iLength <= iThisLineHead) {
                ++resultLineNum;
                styleBegin = [self sci:SCI_POSITIONFROMLINE wParam:(uintptr_t)resultLineNum lParam:0];
                endOfLine = [self sci:SCI_GETLINEENDPOSITION wParam:(uintptr_t)resultLineNum lParam:0];
                continue;
            }
            tlmIdxPosInfo::const_iterator iPosInfo = rlpi.second.posInfos().begin();
            for (; iPosInfo != rlpi.second.posInfos().end(); ++iPosInfo) {
                tclPatternList::const_iterator iPattern = _patStyleList.find(iPosInfo->first);
                if (iPattern == _patStyleList.end()) continue;  // default style already applied
                if (iPattern.getPattern().getSelectionType() == tclPattern::line) {
                    [self setStyle:iPosInfo->first begin:styleBegin + iThisLineHead length:iLength - iThisLineHead];
                } else {
                    tlsPosInfo::const_iterator iFoundPos = iPosInfo->second.begin();
                    for (; iFoundPos != iPosInfo->second.end(); ++iFoundPos) {
                        tiLine iPosInfoLength = (iFoundPos->end - iFoundPos->start);
                        tiLine lineStartInMain = [_controller sci:SCI_POSITIONFROMLINE
                                                            wParam:(uintptr_t)iFoundPos->line lParam:0];
                        tiLine iPosLineBegin = iFoundPos->start - lineStartInMain;
                        if ((iPosInfoLength > 0) && (iPosLineBegin >= 0) &&
                            ((styleBegin + iThisLineHead + iPosLineBegin) >= styleBegin) &&
                            (iPosInfoLength <= (endOfLine - styleBegin))) {
                            [self setStyle:iPosInfo->first
                                     begin:styleBegin + iThisLineHead + iPosLineBegin
                                    length:iPosInfoLength];
                        }
                    }
                }
            }
        }
        ++resultLineNum;
        styleBegin = [self sci:SCI_POSITIONFROMLINE wParam:(uintptr_t)resultLineNum lParam:0];
        endOfLine = [self sci:SCI_GETLINEENDPOSITION
                            wParam:(uintptr_t)(resultLineNum + ((resultLineNum < maxResultLines) ? 2 : 0)) lParam:0];
    } while ((styleBegin < endStyleNeeded) && (resultLineNum < maxResultLines));
}

// ── line-number margin width + recolour after a search ──────────────────────
- (void)updateAfterSearch {
    [self updateLineNumberMargin];
    [self sci:SCI_COLOURISE wParam:0 lParam:-1];
}

- (void)updateLineNumberMargin {
    int linesVisible = (int)[self sci:SCI_LINESONSCREEN wParam:0 lParam:0];
    if (!linesVisible) { [self sci:SCI_SETMARGINWIDTHN wParam:SC_MARGE_LINENUMBER lParam:0]; return; }
    int n = (int)[self sci:SCI_GETLINECOUNT wParam:0 lParam:0];
    int digits = (n < 10) ? 1 : (n < 100) ? 2 : (n < 1000) ? 3 : (n < 10000) ? 4
               : (n < 100000) ? 5 : (n < 1000000) ? 6 : (n < 10000000) ? 7
               : (n < 100000000) ? 8 : (n < 1000000000) ? 9 : 10;
    int charW = (int)[self sci:SCI_TEXTWIDTH wParam:STYLE_LINENUMBER lParam:(intptr_t) "8"];
    int pixelWidth = 4 + digits * charW;
    [self sci:SCI_SETMARGINWIDTHN wParam:SC_MARGE_LINENUMBER lParam:pixelWidth];
}

// ── wrap / font / settings ──────────────────────────────────────────────────
- (void)applyWrapMode {
    [self sci:SCI_SETWRAPMODE wParam:(_wrapMode ? SC_WRAP_WORD : SC_WRAP_NONE) lParam:0];
}
- (void)setWrapMode:(BOOL)wrapMode { _wrapMode = wrapMode; [self applyWrapMode]; }

- (void)setLineNumbersInResult:(BOOL)on {
    _lineNumbersInResult = on;
    [self updateLineNumberMargin];
}

- (void)applyResultFont {
    if (_resultFontName.length == 0) return;
    const char *fn = _resultFontName.UTF8String;
    // Apply to the default + all pattern style slots in use.
    [self sci:SCI_STYLESETFONT wParam:STYLE_DEFAULT lParam:(intptr_t)fn];
    [self sci:SCI_STYLESETSIZE wParam:STYLE_DEFAULT lParam:(intptr_t)_resultFontSize];
    for (unsigned iPat = 0; iPat < _patStyleList.size() && iPat < (unsigned)MY_STYLE_COUNT; ++iPat) {
        int sid = [self transStyleId:iPat];
        [self sci:SCI_STYLESETFONT wParam:(uintptr_t)sid lParam:(intptr_t)fn];
        [self sci:SCI_STYLESETSIZE wParam:(uintptr_t)sid lParam:(intptr_t)_resultFontSize];
    }
}

// ── scroll sync: mirror the main editor's top line into the result ──────────
- (void)syncFromMainTopLine:(tiLine)mainTopLine {
    if (!_syncScroll) return;
    if (_fromFindResult) { _fromFindResult = NO; _fromMainWindow = NO; return; }
    _fromMainWindow = YES;
    tiLine resLine = _findResults.getLineNoAtRes(mainTopLine);
    if (resLine >= 0)
        [self sci:SCI_ENSUREVISIBLEENFORCEPOLICY wParam:(uintptr_t)resLine lParam:0];
}

// ── ScintillaNotificationProtocol ──────────────────────────────────────────
- (void)notification:(SCNotification *)n {
    if (!n) return;
    switch (n->nmhdr.code) {
        case SCN_STYLENEEDED: {
            tiLine startPos = [self sci:SCI_GETENDSTYLED wParam:0 lParam:0];
            tiLine lineNumber = [self sci:SCI_LINEFROMPOSITION wParam:(uintptr_t)startPos lParam:0];
            startPos = [self sci:SCI_POSITIONFROMLINE wParam:(uintptr_t)lineNumber lParam:0];
            [self doStyleFromResultLine:lineNumber startNeeded:startPos endNeeded:(tiLine)n->position];
            break;
        }
        case SCN_DOUBLECLICK: {
            [self handleDoubleClick];
            break;
        }
        case SCN_UPDATEUI: {
            if ((n->updated & SC_UPDATE_V_SCROLL) != 0 && _syncScroll) {
                if (!_fromMainWindow) {
                    _fromFindResult = YES;
                    tiLine top = [self sci:SCI_GETFIRSTVISIBLELINE wParam:0 lParam:0];
                    tiLine mainLine = _findResults.getLineNoAtMain(top);
                    if (mainLine >= 0)
                        [_controller sci:SCI_ENSUREVISIBLEENFORCEPOLICY wParam:(uintptr_t)mainLine lParam:0];
                } else {
                    _fromMainWindow = NO;
                    _fromFindResult = NO;
                }
            }
            break;
        }
        default: break;
    }
}

- (void)handleDoubleClick {
    tiLine currentPos = [self sci:SCI_GETCURRENTPOS wParam:0 lParam:0];
    if (currentPos > 1) {
        char prevChar = (char)[self sci:SCI_GETCHARAT wParam:(uintptr_t)(currentPos - 1) lParam:0];
        if (prevChar == 0x0A && currentPos < [self sci:SCI_GETLENGTH wParam:0 lParam:0])
            currentPos -= 2;  // step back to last char before CRLF
    }
    tiLine resLineNo = [self sci:SCI_LINEFROMPOSITION wParam:(uintptr_t)currentPos lParam:0];
    if (resLineNo >= [self sci:SCI_GETLINECOUNT wParam:0 lParam:0] || _findResults.size() == 0)
        return;
    const tlpLinePosInfo &lineInfo = _findResults.getLineAtRes(resLineNo);
    tiLine lineMain = lineInfo.first;

    // Open (or focus) the source file in the host, then jump to the line.
    BOOL opened = NO;
    if (_searchFileName.length > 0)
        opened = [_controller npp:NPPM_DOOPEN wParam:0 lParam:(intptr_t)_searchFileName.UTF8String] ? YES : NO;
    // Even if DOOPEN reports nothing (e.g. the file is the active untitled doc),
    // still jump in the active editor.
    [self setMarkedLineInMain:lineMain];
    if (!_dblClickJumpsToEditView) {
        // keep focus in the result window
        [self.window makeFirstResponder:_sci];
    }
    (void)opened;
}

@end
