# Analyse Plugin — macOS port

Shorten the time you spend reading megabytes of log files. A dockable **multi-pattern search** plugin for Nextpad++ (the macOS port of Notepad++): search many patterns at once, each in its own colour, and collect every hit in a docked result window you can click to jump back to the source line.

macOS port of Matthias Hessling's Windows [Analyse Plugin](https://sourceforge.net/p/analyseplugin/) (GPLv2). The pattern-matching core is reused; the UI (panels, dialogs, toolbar) is native AppKit.

## Features

- **Pattern list** — define any number of search patterns, each with its own foreground/background colour.
- **Search types** — normal, escaped, regular expression, and multiline regex; with Case and Whole-word options.
- **Per-pattern metadata** — group, order #, comment, hide-text, and line/word selection.
- **Docked result window** (Scintilla-based) — per-pattern colouring, in the same order as the source; **double-click a line to jump** to its position in the editor.
- **Editor margin marks** — matched lines get a green bar in the change-history margin.
- **Result tools** — live filter, zoom, context menu, and RTF/text export.
- **Scroll sync** — bidirectional sync between the result window and the editor.
- **Save / Load** pattern sets as `AnalyseDoc` XML (wire-compatible with the Windows plugin); the active set auto-persists across launches.
- **Options** dialog and **Help / About**.

## What's new in 1.0.1

- **Toolbar on the main panel** — a single borderless button (☰) to **toggle the Analyse Result panel**, so the result window can always be reopened after it's been closed.
- **Search reopens the result panel** — clicking **Search** (or pressing Enter / "Search Now") now makes the Analyse Result panel visible if it was closed, so results are never produced into a hidden panel.
- **Menu checkmark fix** — the **Plugins → Analyse → Show Analyse Dialog** checkmark now clears correctly when you close the panel with its title-bar **✕** (previously it stayed on).

## Menu

**Plugins → Analyse**

- Show Analyse Dialog — toggle the pattern editor + result panels.
- Add selection as search patterns.
- Search now.
- Options… / Help.

## Requirements

- Nextpad++ macOS **v1.0.7 or later** (uses the `NPPM_DMM_*` side-panel docking API).
- macOS 11.0 or later. Universal binary (arm64 + x86_64).

## Install

Install **"Analyse Plugin"** from **Plugins → Plugins Admin…**, or unzip a release into:

```
~/.nextpad++/plugins/AnalysePlugin/AnalysePlugin.dylib
```

Then fully quit and relaunch Nextpad++ (plugins load at startup).

## Build

```bash
cd AnalysePlugin
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(sysctl -n hw.ncpu)
```

Produces a universal `build/AnalysePlugin.dylib`.

## Credits & license

- Original Windows plugin © **Matthias Hessling** — <https://sourceforge.net/p/analyseplugin/>
- macOS port: **Andrey Letov** — <https://github.com/nextpad-plus-plus/AnalysePlugin>
- License: **GPLv2** (see `license.txt`).
