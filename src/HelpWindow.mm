// HelpWindow.mm — see header. Port of the Windows HelpDialog.

#import "HelpWindow.h"
#import <dlfcn.h>
#import <objc/runtime.h>

#define AP_VERSION      @"1.14"
#define AP_AUTHOR       @"Matthias Hessling"
#define AP_EMAIL        @"mattesh@gmx.net"
#define AP_HOMEPAGE     @"https://analyseplugin.sourceforge.io/"

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
    NSRect frame = NSMakeRect(0, 0, 640, 460);
    NSWindow *win = [[NSPanel alloc] initWithContentRect:frame
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                   NSWindowStyleMaskResizable | NSWindowStyleMaskUtilityWindow)
          backing:NSBackingStoreBuffered defer:NO];
    win.title = @"Analyse Plugin Help";
    win.releasedWhenClosed = NO;
    win.minSize = NSMakeSize(420, 280);
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

    NSTextField *title = [NSTextField labelWithString:@"Analyse Plugin for Notepad++"];
    title.font = [NSFont boldSystemFontOfSize:16];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [c addSubview:title];

    NSTextField *ver = [NSTextField labelWithString:[NSString stringWithFormat:@"Version:  %@  (macOS port)", AP_VERSION]];
    NSTextField *auth = [NSTextField labelWithString:[NSString stringWithFormat:@"Author:   %@", AP_AUTHOR]];
    // email + homepage as clickable links
    NSTextField *email = [self linkLabel:[@"mailto:" stringByAppendingString:AP_EMAIL] display:[@"eMail:    " stringByAppendingString:AP_EMAIL]];
    NSTextField *url = [self linkLabel:AP_HOMEPAGE display:[@"URL:      " stringByAppendingString:AP_HOMEPAGE]];
    for (NSTextField *l in @[ver, auth]) {
        l.font = [NSFont systemFontOfSize:11];
        l.translatesAutoresizingMaskIntoConstraints = NO;
        [c addSubview:l];
    }
    [c addSubview:email];
    [c addSubview:url];

    NSButton *manualBtn = [NSButton buttonWithTitle:@"Manual" target:self action:@selector(showManual:)];
    NSButton *changesBtn = [NSButton buttonWithTitle:@"Changes" target:self action:@selector(showChanges:)];
    NSButton *closeBtn = [NSButton buttonWithTitle:@"Close" target:self action:@selector(closeHelp:)];
    closeBtn.keyEquivalent = @"\033";
    for (NSButton *b in @[manualBtn, changesBtn, closeBtn]) {
        b.bezelStyle = NSBezelStyleRounded;
        b.translatesAutoresizingMaskIntoConstraints = NO;
        [c addSubview:b];
    }

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSBezelBorder;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    _textView = [[NSTextView alloc] initWithFrame:NSZeroRect];
    _textView.editable = NO;
    _textView.richText = NO;
    _textView.font = [NSFont userFixedPitchFontOfSize:11];   // monospaced, like Windows "Courier New"
    _textView.automaticQuoteSubstitutionEnabled = NO;
    _textView.horizontallyResizable = NO;
    scroll.documentView = _textView;
    [c addSubview:scroll];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:c.topAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:14],

        [ver.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [ver.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:14],
        [auth.topAnchor constraintEqualToAnchor:ver.bottomAnchor constant:3],
        [auth.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:14],
        [email.topAnchor constraintEqualToAnchor:auth.bottomAnchor constant:3],
        [email.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:14],
        [url.topAnchor constraintEqualToAnchor:email.bottomAnchor constant:3],
        [url.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:14],

        [manualBtn.topAnchor constraintEqualToAnchor:url.bottomAnchor constant:10],
        [manualBtn.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:14],
        [changesBtn.centerYAnchor constraintEqualToAnchor:manualBtn.centerYAnchor],
        [changesBtn.leadingAnchor constraintEqualToAnchor:manualBtn.trailingAnchor constant:8],

        [scroll.topAnchor constraintEqualToAnchor:manualBtn.bottomAnchor constant:10],
        [scroll.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:14],
        [scroll.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-14],
        [scroll.bottomAnchor constraintEqualToAnchor:closeBtn.topAnchor constant:-10],

        [closeBtn.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-14],
        [closeBtn.bottomAnchor constraintEqualToAnchor:c.bottomAnchor constant:-12],
        [closeBtn.widthAnchor constraintEqualToConstant:84],
    ]];
}

- (NSTextField *)linkLabel:(NSString *)urlStr display:(NSString *)display {
    NSTextField *l = [NSTextField labelWithString:display];
    l.font = [NSFont systemFontOfSize:11];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.selectable = YES;
    // simple click-to-open via a gesture
    NSClickGestureRecognizer *g = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(openLink:)];
    g.numberOfClicksRequired = 1;
    l.toolTip = urlStr;
    objc_setAssociatedObject(l, "url", urlStr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [l addGestureRecognizer:g];
    return l;
}

- (void)openLink:(NSClickGestureRecognizer *)g {
    NSString *u = objc_getAssociatedObject(g.view, "url");
    if (u) [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:u]];
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
