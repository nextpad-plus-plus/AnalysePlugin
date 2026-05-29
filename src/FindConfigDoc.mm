// FindConfigDoc.mm — AnalyseDoc XML read/write over NSXMLDocument. See header.

#import <Foundation/Foundation.h>
#include "FindConfigDoc.h"
#include "tclPattern.h"

// Element / attribute names — must match AnalyseDoc.xsd exactly.
static NSString *const kElAnalyseDoc = @"AnalyseDoc";
static NSString *const kElSearchText = @"SearchText";
static NSString *const kAtOrderNum   = @"orderNum";
static NSString *const kAtDoSearch   = @"doSearch";
static NSString *const kAtSearchType = @"searchType";
static NSString *const kAtMatchCase  = @"matchCase";
static NSString *const kAtWholeWord  = @"wholeWord";
static NSString *const kAtSelect     = @"select";
static NSString *const kAtHide       = @"hide";
static NSString *const kAtBold       = @"bold";
static NSString *const kAtItalic     = @"italic";
static NSString *const kAtUnderlined = @"underlined";
static NSString *const kAtColor      = @"color";
static NSString *const kAtBgColor    = @"bgColor";
static NSString *const kAtComment    = @"comment";
static NSString *const kAtGroup      = @"group";
static NSString *const kAtHits       = @"hits";

static NSString *attr(NSXMLElement *e, NSString *name) {
    NSXMLNode *a = [e attributeForName:name];
    NSString *v = a.stringValue;
    return (v.length > 0) ? v : nil;
}

static std::string cppstr(NSString *s) { return std::string(s.UTF8String ?: ""); }

namespace APConfigDoc {

bool readPatternList(const std::string &path, tclPatternList &pl,
                     bool bAppend, bool bLoadNew, std::string &err) {
    @autoreleasepool {
        NSURL *url = [NSURL fileURLWithPath:@(path.c_str())];
        NSError *nserr = nil;
        // Preserve intentional whitespace in the search text (matches the
        // Windows tinyxml SetCondenseWhiteSpace(false)).
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:url
                                                                 options:NSXMLNodePreserveWhitespace
                                                                   error:&nserr];
        if (!doc) { err = nserr.localizedDescription.UTF8String ?: "parse error"; return false; }

        NSXMLElement *root = doc.rootElement;
        if (!root || ![root.name isEqualToString:kElAnalyseDoc]) {
            err = "missing <AnalyseDoc> root";
            return false;
        }
        if (bLoadNew) pl.clear();

        NSArray<NSXMLElement *> *elems = [root elementsForName:kElSearchText];
        // Prepend (non-append) walks in reverse so insertion order is preserved.
        NSEnumerator *en = bAppend ? elems.objectEnumerator : elems.reverseObjectEnumerator;
        for (NSXMLElement *elem in en) {
            tclPattern p;
            // Element text content = the search pattern (verbatim).
            NSString *text = elem.stringValue ?: @"";
            p.setSearchText(cppstr(text));

            NSString *v;
            if ((v = attr(elem, kAtOrderNum)))   p.setOrderNumStr(cppstr(v));
            if ((v = attr(elem, kAtDoSearch)))   p.setDoSearchStr(cppstr(v));
            if ((v = attr(elem, kAtSearchType))) p.setSearchTypeStr(cppstr(v));
            if ((v = attr(elem, kAtMatchCase)))  p.setMatchCaseStr(cppstr(v));
            if ((v = attr(elem, kAtWholeWord)))  p.setWholeWordStr(cppstr(v));
            if ((v = attr(elem, kAtSelect)))     p.setSelectionTypeStr(cppstr(v));
            if ((v = attr(elem, kAtHide)))       p.setHideTextStr(cppstr(v));
            if ((v = attr(elem, kAtBold)))       p.setBoldStr(cppstr(v));
            if ((v = attr(elem, kAtItalic)))     p.setItalicStr(cppstr(v));
            if ((v = attr(elem, kAtUnderlined))) p.setUnderlinedStr(cppstr(v));
            if ((v = attr(elem, kAtColor)))      p.setColorStr(cppstr(v));
            if ((v = attr(elem, kAtBgColor)))    p.setBgColorStr(cppstr(v));
            if ((v = attr(elem, kAtComment)))    p.setComment(cppstr(v));
            if ((v = attr(elem, kAtGroup)))      p.setGroup(cppstr(v));

            if (bAppend) pl.push_back(p);
            else         pl.insert(pl.begin().getPatId(), p);
        }
        return true;
    }
}

// Build the <AnalyseDoc> element tree from pl (shared by write paths).
static NSXMLElement *buildDoc(tclPatternList &pl) {
    NSXMLElement *root = [NSXMLElement elementWithName:kElAnalyseDoc];
    [root addAttribute:[NSXMLNode attributeWithName:@"xmlns:xsi"
                                        stringValue:@"http://www.w3.org/2001/XMLSchema-instance"]];
    [root addAttribute:[NSXMLNode attributeWithName:@"xsi:noNamespaceSchemaLocation"
                                        stringValue:@"./AnalyseDoc.xsd"]];
    tclPattern defP;
    for (unsigned i = 0; i < pl.size(); ++i) {
        const tclPattern &rp = pl.getPattern(pl.getPatternId(i));
        NSXMLElement *e = [NSXMLElement elementWithName:kElSearchText];
        // Element text = the search pattern.
        [e setStringValue:@(rp.getSearchText().c_str())];

        auto setA = [&](NSString *name, const generic_string &val) {
            [e addAttribute:[NSXMLNode attributeWithName:name stringValue:@(val.c_str())]];
        };
        if (rp.getOrderNumStr() != defP.getOrderNumStr())     setA(kAtOrderNum, rp.getOrderNumStr());
        if (rp.getDoSearch() != defP.getDoSearch())           setA(kAtDoSearch, rp.getDoSearchStr());
        if (rp.getSearchType() != defP.getSearchType())       setA(kAtSearchType, rp.getSearchTypeStr());
        if (rp.getIsMatchCase() != defP.getIsMatchCase())     setA(kAtMatchCase, rp.getMatchCaseStr());
        if (rp.getIsWholeWord() != defP.getIsWholeWord())     setA(kAtWholeWord, rp.getWholeWordStr());
        if (rp.getSelectionType() != defP.getSelectionType()) setA(kAtSelect, rp.getSelectionTypeStr());
        if (rp.getIsHideText() != defP.getIsHideText())       setA(kAtHide, rp.getHideTextStr());
        if (rp.getIsBold() != defP.getIsBold())               setA(kAtBold, rp.getBoldStr());
        if (rp.getIsItalic() != defP.getIsItalic())           setA(kAtItalic, rp.getItalicStr());
        if (rp.getIsUnderlined() != defP.getIsUnderlined())   setA(kAtUnderlined, rp.getUnderlinedStr());
        if (rp.getColor() != defP.getColor())                 setA(kAtColor, rp.getColorStr());
        if (rp.getBgColor() != defP.getBgColor())             setA(kAtBgColor, rp.getBgColorStr());
        if (!rp.getComment().empty())                         setA(kAtComment, rp.getComment());
        if (!rp.getGroup().empty())                           setA(kAtGroup, rp.getGroup());

        [root addChild:e];
    }
    return root;
}

static bool writeDoc(NSXMLElement *root, const std::string &path, std::string &err) {
    @autoreleasepool {
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithRootElement:root];
        doc.version = @"1.0";
        doc.characterEncoding = @"UTF-8";
        doc.standalone = NO;
        // NOTE: no NSXMLNodePrettyPrint — it would reflow SearchText content and
        // could alter intentional leading/trailing whitespace in a pattern.
        NSData *data = [doc XMLDataWithOptions:NSXMLNodeOptionsNone];
        NSError *nserr = nil;
        BOOL ok = [data writeToURL:[NSURL fileURLWithPath:@(path.c_str())]
                           options:NSDataWritingAtomic error:&nserr];
        if (!ok) { err = nserr.localizedDescription.UTF8String ?: "write error"; return false; }
        return true;
    }
}

bool writePatternList(const std::string &path, tclPatternList &pl, std::string &err) {
    return writeDoc(buildDoc(pl), path, err);
}

bool writePatternHitsList(const std::string &path, tclResultList &rl, std::string &err) {
    NSXMLElement *root = buildDoc(rl);
    // Annotate each <SearchText> with its hit count (only for non-dirty results).
    NSArray<NSXMLElement *> *elems = [root elementsForName:kElSearchText];
    for (unsigned i = 0; i < rl.size() && i < elems.count; ++i) {
        const tclResult &rr = rl.refResult(rl.getPatternId(i));
        if (rr.getIsDirty()) continue;
        NSXMLElement *e = elems[i];
        [e addAttribute:[NSXMLNode attributeWithName:kAtHits
                                         stringValue:[NSString stringWithFormat:@"%u", rr.size()]]];
    }
    return writeDoc(root, path, err);
}

}  // namespace APConfigDoc
