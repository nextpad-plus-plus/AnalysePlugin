// FindConfigDoc.h (macOS port) — read/write the pattern list as AnalyseDoc XML.
//
// Wire-compatible with the Windows plugin: same AnalyseDoc.xsd schema
// (<AnalyseDoc><SearchText attrs…>pattern text</SearchText>…), attributes
// written only when they differ from the default pattern. Implemented over
// NSXMLDocument in FindConfigDoc.mm.

#pragma once

#include "tclPatternList.h"
#include "tclResultList.h"
#include <string>

namespace APConfigDoc {

// Load patterns from an XML file into pl. bLoadNew clears pl first; bAppend
// appends (vs. prepends). Returns true on success; err gets a message on failure.
bool readPatternList(const std::string &path, tclPatternList &pl,
                     bool bAppend, bool bLoadNew, std::string &err);

// Write pl to an XML file (AnalyseDoc schema). Returns true on success.
bool writePatternList(const std::string &path, tclPatternList &pl, std::string &err);

// Like writePatternList but also records a `hits` count per pattern.
bool writePatternHitsList(const std::string &path, tclResultList &rl, std::string &err);

}  // namespace APConfigDoc
