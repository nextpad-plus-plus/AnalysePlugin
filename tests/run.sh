#!/bin/bash
# Build + run the standalone edge-case tests for the portable core / XML config.
set -e
cd "$(dirname "$0")/.."
clang++ -std=c++17 -fobjc-arc -framework Foundation \
  -I deps -I src \
  tests/test_xml.mm \
  src/FindConfigDoc.mm src/tclPattern.cpp src/tclColor.cpp \
  src/tclPatternList.cpp src/tclResult.cpp src/tclResultList.cpp src/tclFindResultDoc.cpp \
  -o /tmp/ap_test_xml
/tmp/ap_test_xml
