// test_xml.mm — standalone edge-case round-trip test for the AnalyseDoc XML
// config (FindConfigDoc). Build + run via tests/run.sh.

#import <Foundation/Foundation.h>
#include "FindConfigDoc.h"
#include "tclPattern.h"
#include "tclResultList.h"
#include <cstdio>
#include <string>

static int g_fail = 0;
static void check(bool cond, const char *what) {
    printf("  [%s] %s\n", cond ? "PASS" : "FAIL", what);
    if (!cond) g_fail++;
}

static std::string readFile(const std::string &path) {
    NSString *s = [NSString stringWithContentsOfFile:@(path.c_str()) encoding:NSUTF8StringEncoding error:nil];
    return std::string(s.UTF8String ?: "");
}

int main() {
    @autoreleasepool {
        const std::string f1 = "/tmp/ap_xml_test1.xml";
        const std::string f2 = "/tmp/ap_xml_test2.xml";
        std::string err;

        tclPatternList pl;

        // 1. XML special characters in search text + comment.
        { tclPattern p; p.setSearchText("<tag attr=\"v\"> & 'x' </tag>");
          p.setComment("comment <&> \"q\""); p.setColorStr("red"); pl.push_back(p); }
        // 2. Leading/trailing/intentional inner whitespace must survive verbatim.
        { tclPattern p; p.setSearchText("   spaced   inner   "); pl.push_back(p); }
        // 3. regex + multiline + all boolean attrs + group + order.
        { tclPattern p; p.setSearchText("^ERROR.*$"); p.setSearchType(tclPattern::regex);
          p.setMatchCase(true); p.setWholeWord(true); p.setHideText(true);
          p.setSelectionType(0 /*text*/); p.setGroup("grpA"); p.setOrderNumStr("0007");
          p.setColorStr("blue"); p.setBgColorStr("yellow"); pl.push_back(p); }
        // 4. escaped type + custom #hex colour.
        { tclPattern p; p.setSearchText("tab\\tsep"); p.setSearchType(tclPattern::escaped);
          p.setColorStr("#123456"); pl.push_back(p); }
        // 5. rgx_multiline, doSearch off.
        { tclPattern p; p.setSearchText("multi\\nline"); p.setSearchType(tclPattern::rgx_multiline);
          p.setDoSearch(false); pl.push_back(p); }
        // 6. Unicode in search text + comment.
        { tclPattern p; p.setSearchText("café — naïve — 日本語"); p.setComment("ünïcödé"); pl.push_back(p); }

        check(APConfigDoc::writePatternList(f1, pl, err), "write list1");

        tclPatternList pl2;
        check(APConfigDoc::readPatternList(f1, pl2, true, true, err), "read list1 → list2");
        check(pl2.size() == pl.size(), "pattern count preserved");

        // Field-level checks on the read-back list.
        check(pl2.size() >= 6, "have 6 patterns");
        if (pl2.size() >= 6) {
            check(pl2.getPattern(pl2.getPatternId(0)).getSearchText() == "<tag attr=\"v\"> & 'x' </tag>",
                  "special-char search text verbatim");
            check(pl2.getPattern(pl2.getPatternId(1)).getSearchText() == "   spaced   inner   ",
                  "whitespace preserved verbatim");
            check(pl2.getPattern(pl2.getPatternId(2)).getSearchType() == tclPattern::regex,
                  "regex type round-trips");
            check(pl2.getPattern(pl2.getPatternId(2)).getIsMatchCase() &&
                  pl2.getPattern(pl2.getPatternId(2)).getIsWholeWord() &&
                  pl2.getPattern(pl2.getPatternId(2)).getIsHideText(),
                  "boolean attrs round-trip");
            check(pl2.getPattern(pl2.getPatternId(2)).getOrderNumStr() == "0007",
                  "orderNum round-trips");
            check(pl2.getPattern(pl2.getPatternId(3)).getSearchType() == tclPattern::escaped,
                  "escaped type round-trips");
            check(pl2.getPattern(pl2.getPatternId(4)).getDoSearch() == false,
                  "doSearch=false round-trips");
            check(pl2.getPattern(pl2.getPatternId(5)).getSearchText() == "café — naïve — 日本語",
                  "unicode search text round-trips");
            check(pl2.getPattern(pl2.getPatternId(5)).getComment() == "ünïcödé",
                  "unicode comment round-trips");
        }

        // Stability: write list2 → file2; the two files must be byte-identical.
        check(APConfigDoc::writePatternList(f2, pl2, err), "write list2");
        check(readFile(f1) == readFile(f2), "write→read→write is byte-stable");

        // Empty list edge case.
        { tclPatternList empty; std::string e;
          check(APConfigDoc::writePatternList("/tmp/ap_xml_empty.xml", empty, e), "write empty list");
          tclPatternList back; check(APConfigDoc::readPatternList("/tmp/ap_xml_empty.xml", back, true, true, e),
                                     "read empty list");
          check(back.size() == 0, "empty list round-trips to 0"); }

        printf("\n%s (%d failures)\n", g_fail ? "TESTS FAILED" : "ALL TESTS PASSED", g_fail);
        return g_fail ? 1 : 0;
    }
}
