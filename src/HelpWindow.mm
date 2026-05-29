// HelpWindow.mm — see header. Centered About-style header (matching the other
// released macOS plugins) + a monospaced Manual/Changes text area.

#import "HelpWindow.h"
#import <dlfcn.h>

#define AP_VERSION   @"1.0.0"
#define AP_PROJECT   @"https://github.com/nextpad-plus-plus/AnalysePlugin"
#define AP_DESC      @"Native macOS port of the Notepad++ Analyse Plugin. Dockable "\
                      "multi-pattern search with per-pattern colors, a results panel, "\
                      "and double-click jump to the matching line."

// Directory the plugin dylib lives in (manual.txt / changes.txt are installed there).
static NSString *pluginDir(void) {
    Dl_info info;
    if (dladdr((const void *)&pluginDir, &info) && info.dli_fname)
        return [@(info.dli_fname) stringByDeletingLastPathComponent];
    return nil;
}
static NSString *readDoc(NSString *name) {
    NSString *dir = pluginDir();
    if (!dir) return @"";
    NSString *path = [dir stringByAppendingPathComponent:name];
    NSString *s = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    return s ?: [NSString stringWithFormat:@"(%@ not found)", name];
}

@implementation HelpWindow {
    NSTextView *_textView;
    NSString   *_manual;
    NSString   *_changes;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 600, 520);
    NSWindow *win = [[NSPanel alloc] initWithContentRect:frame
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                   NSWindowStyleMaskResizable | NSWindowStyleMaskUtilityWindow)
          backing:NSBackingStoreBuffered defer:NO];
    win.title = @"About Analyse Plugin";
    win.releasedWhenClosed = NO;
    win.minSize = NSMakeSize(440, 360);
    if ((self = [super initWithWindow:win])) {
        _manual = readDoc(@"manual.txt");
        _changes = readDoc(@"changes.txt");
        [self buildUI];
        [self showText:_manual];
    }
    return self;
}

- (void)buildUI {
    NSView *c = self.window.contentView;

    // ── Centered About header (matches the other released plugins) ───────────
    NSTextField *title = [NSTextField labelWithString:@"Analyse Plugin for macOS"];
    title.font = [NSFont boldSystemFontOfSize:18];
    title.alignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *desc = [NSTextField wrappingLabelWithString:AP_DESC];
    desc.font = [NSFont systemFontOfSize:13];
    desc.alignment = NSTextAlignmentCenter;
    desc.selectable = NO;
    desc.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *ported = [NSTextField labelWithString:@"ported by Andrey Letov"];
    ported.font = [NSFont systemFontOfSize:12];
    ported.alignment = NSTextAlignmentCenter;
    ported.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *ver = [NSTextField labelWithString:[@"Version " stringByAppendingString:AP_VERSION]];
    ver.font = [NSFont systemFontOfSize:12];
    ver.alignment = NSTextAlignmentCenter;
    ver.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *project = [NSButton buttonWithTitle:[@"Project: " stringByAppendingString:AP_PROJECT]
                                           target:self action:@selector(openProject:)];
    project.bezelStyle = NSBezelStyleInline;
    project.bordered = NO;
    project.font = [NSFont systemFontOfSize:12];
    project.contentTintColor = [NSColor linkColor];
    project.translatesAutoresizingMaskIntoConstraints = NO;

    // ── Manual / Changes buttons ─────────────────────────────────────────────
    NSButton *manualBtn = [self smallButton:@"Manual" action:@selector(showManual:)];
    NSButton *changesBtn = [self smallButton:@"Changes" action:@selector(showChanges:)];
    NSButton *closeBtn = [self smallButton:@"Close" action:@selector(closeHelp:)];
    closeBtn.keyEquivalent = @"\033";

    // ── Manual/Changes text area ─────────────────────────────────────────────
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 560, 280)];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSBezelBorder;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;

    _textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 560, 280)];
    _textView.editable = NO;
    _textView.richText = NO;
    _textView.font = [NSFont userFixedPitchFontOfSize:11];   // monospaced (≈ Courier New)
    _textView.minSize = NSMakeSize(0, 0);
    _textView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    _textView.verticallyResizable = YES;                     // (the missing bit — text was 0-height)
    _textView.horizontallyResizable = NO;
    _textView.autoresizingMask = NSViewWidthSizable;
    _textView.textContainerInset = NSMakeSize(4, 4);
    _textView.textContainer.widthTracksTextView = YES;
    scroll.documentView = _textView;

    for (NSView *v in @[title, desc, ported, ver, project, manualBtn, changesBtn, closeBtn, scroll])
        [c addSubview:v];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:c.topAnchor constant:16],
        [title.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-20],

        [desc.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10],
        [desc.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:30],
        [desc.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-30],

        [ported.topAnchor constraintEqualToAnchor:desc.bottomAnchor constant:12],
        [ported.centerXAnchor constraintEqualToAnchor:c.centerXAnchor],
        [ver.topAnchor constraintEqualToAnchor:ported.bottomAnchor constant:4],
        [ver.centerXAnchor constraintEqualToAnchor:c.centerXAnchor],
        [project.topAnchor constraintEqualToAnchor:ver.bottomAnchor constant:2],
        [project.centerXAnchor constraintEqualToAnchor:c.centerXAnchor],

        [manualBtn.topAnchor constraintEqualToAnchor:project.bottomAnchor constant:14],
        [manualBtn.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:20],
        [changesBtn.centerYAnchor constraintEqualToAnchor:manualBtn.centerYAnchor],
        [changesBtn.leadingAnchor constraintEqualToAnchor:manualBtn.trailingAnchor constant:8],

        [scroll.topAnchor constraintEqualToAnchor:manualBtn.bottomAnchor constant:10],
        [scroll.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:20],
        [scroll.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-20],
        [scroll.bottomAnchor constraintEqualToAnchor:closeBtn.topAnchor constant:-10],

        [closeBtn.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-20],
        [closeBtn.bottomAnchor constraintEqualToAnchor:c.bottomAnchor constant:-14],
        [closeBtn.widthAnchor constraintEqualToConstant:84],
    ]];
}

- (NSButton *)smallButton:(NSString *)title action:(SEL)sel {
    NSButton *b = [NSButton buttonWithTitle:title target:self action:sel];
    b.bezelStyle = NSBezelStyleRounded;
    b.controlSize = NSControlSizeRegular;
    b.font = [NSFont systemFontOfSize:13];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

- (void)openProject:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:AP_PROJECT]];
}

- (void)showText:(NSString *)t {
    [_textView setString:t ?: @""];
    [_textView scrollRangeToVisible:NSMakeRange(0, 0)];
}
- (void)showManual:(id)sender  { [self showText:_manual]; }
- (void)showChanges:(id)sender { [self showText:_changes]; }
- (void)closeHelp:(id)sender   { [self.window close]; }

- (void)showHelp {
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
}

@end
