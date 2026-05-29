/* -------------------------------------
APCompat.h — Win32/NPP compatibility shim for the macOS port of AnalysePlugin.

The portable C++ core (tclPattern, tclColor, tclResult, …) was written against
<windows.h> and Notepad++'s Common.h. On macOS we model strings as UTF-8
(std::string) to match both the host and Scintilla's byte-oriented API, and
provide narrow equivalents of the few generic_* / Win32 helpers the core uses.

Each ported core file includes THIS instead of <windows.h> + "Common.h".
------------------------------------- */
#ifndef AP_COMPAT_H
#define AP_COMPAT_H

#include <string>
#include <cstdint>
#include <cstdlib>
#include <cstdio>
#include <cassert>
#include <cstring>

// UTF-8 narrow string model (matches host char* convention + Scintilla bytes).
typedef std::string generic_string;

#ifndef TCHAR
typedef char TCHAR;
#endif
#ifndef TEXT
#define TEXT(x) x
#endif

// ── Win32 colour (0x00BBGGRR) ───────────────────────────────────────────────
typedef uint32_t COLORREF;
#ifndef RGB
#define RGB(r, g, b) ((COLORREF)(((uint8_t)(r)) | (((uint8_t)(g)) << 8) | (((uint8_t)(b)) << 16)))
#endif
#ifndef GetRValue
#define GetRValue(c) ((uint8_t)((c) & 0xFF))
#define GetGValue(c) ((uint8_t)(((c) >> 8) & 0xFF))
#define GetBValue(c) ((uint8_t)(((c) >> 16) & 0xFF))
#endif

// ── Narrow equivalents of the NPP generic_* helpers used by the core ────────
// generic_itoa(value, buffer, radix): mirrors _itot's base-10/base-16 output
// (lowercase hex, matching Windows _itoa).
inline TCHAR *generic_itoa(long val, TCHAR *buf, int radix) {
    // Caller-provided buffer (same contract as Win32 _itot). Format into a
    // bounded scratch buffer then copy, to keep snprintf's safety.
    char tmp[32];
    if (radix == 16)
        std::snprintf(tmp, sizeof tmp, "%lx", (unsigned long)val);
    else
        std::snprintf(tmp, sizeof tmp, "%ld", val);
    std::strcpy(buf, tmp);
    return buf;
}
inline long generic_strtol(const TCHAR *s, TCHAR **end, int base) {
    return std::strtol(s, end, base);
}
inline int generic_atoi(const TCHAR *s) { return std::atoi(s); }

// 64-bit itoa (used by result-line numbering + RTF export).
inline TCHAR *generic_i64toa(long long val, TCHAR *buf, int radix) {
    char tmp[32];
    if (radix == 16)
        std::snprintf(tmp, sizeof tmp, "%llx", (unsigned long long)val);
    else
        std::snprintf(tmp, sizeof tmp, "%lld", val);
    std::strcpy(buf, tmp);
    return buf;
}
#ifndef _i64toa
#define _i64toa generic_i64toa
#endif

#endif // AP_COMPAT_H
