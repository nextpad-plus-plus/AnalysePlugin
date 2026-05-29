/* -------------------------------------
MyPlugin.h (macOS port) — minimal shared types for the portable C++ core.

The Windows original declared a fat virtual callback interface (MyPlugin) that
the Win32 dock windows implemented. On macOS that role is played by the ObjC
AnalyseController, so this header keeps ONLY the type the data model needs:
the pattern id type and the two small enums the core / UI share.
------------------------------------- */
#ifndef MYPLUGIN_H
#define MYPLUGIN_H

// Pattern id. A double so new ids can be slotted between two existing ones via
// a fractional midpoint without renumbering the whole list (see tclPatternList).
typedef double tPatId;

// How the pattern-editor reacts to pressing Enter in the search field.
enum teOnEnterAction {
    enOnEntNoAction = 0,   // "just search"
    enOnEntUpdate,         // "update line"
    enOnEntAdd             // "add line"
};

// Which editor view a host message targets.
enum class teNppWindows {
    scnMainHandle,
    scnSecondHandle,
    nppHandle,
    scnActiveHandle   // whichever (main or sub) is currently active
};

#endif // MYPLUGIN_H
