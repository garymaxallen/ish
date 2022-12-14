//
//  ViewController.m
//  iSH
//
//  Created by Theodore Dubois on 10/17/17.
//

#import "TerminalViewController.h"
#import "AppDelegate.h"
#import "TerminalView.h"
#import "BarButton.h"
#import "ArrowBarButton.h"
#import "UserPreferences.h"
#import "AboutViewController.h"
#import "CurrentRoot.h"
#import "NSObject+SaneKVO.h"
#import "LinuxInterop.h"
#include "kernel/init.h"
#include "kernel/task.h"
#include "kernel/calls.h"
#include "fs/devices.h"

@interface TerminalViewController () <UIGestureRecognizerDelegate>

@property UITapGestureRecognizer *tapRecognizer;
//@property (weak, nonatomic) IBOutlet TerminalView *termView;
@property TerminalView *termView;
@property UIView *kbView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

@property (weak, nonatomic) IBOutlet UIButton *tabKey;
@property (weak, nonatomic) IBOutlet UIButton *controlKey;
@property (weak, nonatomic) IBOutlet UIButton *escapeKey;
@property (strong, nonatomic) IBOutletCollection(id) NSArray *barButtons;
@property (strong, nonatomic) IBOutletCollection(id) NSArray *barControls;

@property (weak, nonatomic) IBOutlet UIInputView *barView;
@property (weak, nonatomic) IBOutlet UIStackView *bar;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barLeading;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barTrailing;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barButtonWidth;
@property (weak, nonatomic) IBOutlet UIView *settingsBadge;

@property (weak, nonatomic) IBOutlet UIButton *infoButton;
@property (weak, nonatomic) IBOutlet UIButton *pasteButton;
@property (weak, nonatomic) IBOutlet UIButton *hideKeyboardButton;

@property int sessionPid;
@property (nonatomic) Terminal *sessionTerminal;

@property BOOL ignoreKeyboardMotion;
@property (nonatomic) BOOL hasExternalKeyboard;

@end

@implementation TerminalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [self listFonts];
    [self listViews];
    [self setKeyboardView2];

    int bootError = [AppDelegate bootError];
    if (bootError < 0) {
        NSString *message = [NSString stringWithFormat:@"could not boot"];
        NSString *subtitle = [NSString stringWithFormat:@"error code %d", bootError];
        if (bootError == _EINVAL)
            subtitle = [subtitle stringByAppendingString:@"\n(try reinstalling the app, see release notes for details)"];
        [self showMessage:message subtitle:subtitle];
        NSLog(@"boot failed with code %d", bootError);
    }
    
    self.termView = [[TerminalView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.view addSubview: self.termView];

    self.terminal = self.terminal;
    self.termView.canBecomeFirstResponder = true;
    self.termView.inputAccessoryView = self.kbView;
    [self.termView becomeFirstResponder];
    self.termView.keyboardAppearance = UIKeyboardAppearanceDark;
//    self.view.backgroundColor = UIColor.systemBlueColor;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(keyboardDidSomething:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(keyboardDidSomething:)
                   name:UIKeyboardDidChangeFrameNotification
                 object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(processExited:)
                                               name:ProcessExitedNotification
                                             object:nil];
}

- (void)listViews {
    for (UIView *view in [self.bar subviews])
    {
        if ([view isKindOfClass:[ArrowBarButton class]] || [view.accessibilityIdentifier isEqual: @"ggggg"]){
//            NSLog(@"view.description: %@", view.description);
//            NSLog(@"view.class: %@", view.class);
//            NSLog(@"view.restorationIdentifier: %@", view.restorationIdentifier);
            [view removeFromSuperview];
        }
    }
}

- (void)listFonts {
    NSString *family;
    NSString *font;
    for (family in UIFont.familyNames) {
        NSLog(@"family: %@", family);
        for (font in [UIFont fontNamesForFamilyName:family]) {
            NSLog(@"font: %@", font);
        }
    }
}

- (void)setKeyboardView2 {
    UIButton *escapeKey = [UIButton buttonWithType: UIButtonTypeSystem];
    [escapeKey setFrame: CGRectMake(0.0, 0.0, 40.0, 40.0)];
    [escapeKey setTitle: @"ESC" forState: UIControlStateNormal];
    [escapeKey setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [escapeKey setBackgroundColor: [UIColor whiteColor]];
    [escapeKey addTarget: self action: @selector(pressEscape:) forControlEvents: UIControlEventTouchUpInside];
    
    UIButton *tabKey = [UIButton buttonWithType: UIButtonTypeSystem];
    [tabKey setFrame: CGRectMake(40.0, 0.0, 40.0, 40.0)];
    [tabKey setTitle: @"TAB" forState: UIControlStateNormal];
    [tabKey setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [tabKey setBackgroundColor: [UIColor whiteColor]];
    [tabKey addTarget: self action: @selector(pressTab) forControlEvents: UIControlEventTouchUpInside];
    
//    self.controlKey = [UIButton buttonWithType: UIButtonTypeSystem];
//    [self.controlKey setFrame: CGRectMake(80.0, 0.0, 40.0, 40.0)];
//    [self.controlKey setTitle: @"CTRL" forState: UIControlStateNormal];
//    [self.controlKey setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
//    [self.controlKey setBackgroundColor: [UIColor whiteColor]];
//    [self.controlKey addTarget: self action: @selector(pressControl:) forControlEvents: UIControlEventTouchUpInside];
//    self.termView.controlKey = self.controlKey;
    
    UIButton *leftButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [leftButton setFrame: CGRectMake(120.0, 0.0, 40.0, 40.0)];
    [leftButton setTitle: @"???" forState: UIControlStateNormal];
    [leftButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [leftButton setBackgroundColor: [UIColor whiteColor]];
    [leftButton addTarget: self action: @selector(pressLeft) forControlEvents: UIControlEventTouchUpInside];
    
    UIButton *rightButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [rightButton setFrame: CGRectMake(160.0, 0.0, 40.0, 40.0)];
    [rightButton setTitle: @"???" forState: UIControlStateNormal];
    [rightButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [rightButton setBackgroundColor: [UIColor whiteColor]];
    [rightButton addTarget: self action: @selector(pressRight) forControlEvents: UIControlEventTouchUpInside];
    
    UIButton *upButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [upButton setFrame: CGRectMake(200.0, 0.0, 40.0, 40.0)];
    [upButton setTitle: @"???" forState: UIControlStateNormal];
    [upButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [upButton setBackgroundColor: [UIColor whiteColor]];
    [upButton addTarget: self action: @selector(pressUp) forControlEvents: UIControlEventTouchUpInside];
    
    UIButton *downButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [downButton setFrame: CGRectMake(240.0, 0.0, 40.0, 40.0)];
    [downButton setTitle: @"???" forState: UIControlStateNormal];
    [downButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [downButton setBackgroundColor: [UIColor whiteColor]];
    [downButton addTarget: self action: @selector(pressDown) forControlEvents: UIControlEventTouchUpInside];
    
    UIButton *pasteButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [pasteButton setFrame: CGRectMake(280.0, 0.0, 40.0, 40.0)];
    [pasteButton setTitle: @"???????" forState: UIControlStateNormal];
    [pasteButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [pasteButton setBackgroundColor: [UIColor whiteColor]];
    [pasteButton addTarget: self action: @selector(pressPaste) forControlEvents: UIControlEventTouchUpInside];
    
    UIButton *hideKeyboardButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [hideKeyboardButton setFrame: CGRectMake(320.0, 0.0, 40.0, 40.0)];
    [hideKeyboardButton setTitle: @"??????" forState: UIControlStateNormal];
    [hideKeyboardButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [hideKeyboardButton setBackgroundColor: [UIColor whiteColor]];
    [hideKeyboardButton addTarget: self action: @selector(hideKeyboard) forControlEvents: UIControlEventTouchUpInside];
    
    self.kbView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 40)];
    self.kbView.backgroundColor = [UIColor whiteColor];
    [self.kbView addSubview:escapeKey];
    [self.kbView addSubview:tabKey];
//    [kbView addSubview:self.controlKey];
    [self.kbView addSubview:leftButton];
    [self.kbView addSubview:rightButton];
    [self.kbView addSubview:upButton];
    [self.kbView addSubview:downButton];
    [self.kbView addSubview:pasteButton];
    [self.kbView addSubview:hideKeyboardButton];
}

- (void)setKeyboardView {
    [self.tabKey setTitle:@"TAB" forState:UIControlStateNormal];
    [self.tabKey setImage:nil forState:UIControlStateNormal];
    [self.tabKey.titleLabel setFont:[UIFont systemFontOfSize:16]];
    
    [self.controlKey setTitle:@"CTRL" forState:UIControlStateNormal];
    [self.controlKey setImage:nil forState:UIControlStateNormal];
    [self.controlKey.titleLabel setFont:[UIFont systemFontOfSize:12]];
    
    [self.escapeKey setImage:nil forState:UIControlStateNormal];
    [self.escapeKey setTitle: @"ESC" forState: UIControlStateNormal];
    [self.escapeKey.titleLabel setFont:[UIFont systemFontOfSize:16]];
    
    UIButton *leftButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [leftButton.titleLabel setFont:[UIFont systemFontOfSize:24]];
    [leftButton setFrame:CGRectMake(111, 0, 31, 43)];
    [leftButton setTitle:@"???" forState:UIControlStateNormal];
    leftButton.backgroundColor = UIColor.whiteColor;
    leftButton.layer.cornerRadius = 5;
    leftButton.layer.shadowOffset = CGSizeMake(0, 1);
    leftButton.layer.shadowOpacity = 0.4;
    leftButton.layer.shadowRadius = 0;
    [leftButton addTarget: self action: @selector(pressLeft) forControlEvents: UIControlEventTouchUpInside];
    [self.bar addSubview:leftButton];
    
    UIButton *rightButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [rightButton.titleLabel setFont:[UIFont systemFontOfSize:24]];
    [rightButton setFrame:CGRectMake(148, 0, 31, 43)];
    [rightButton setTitle:@"???" forState:UIControlStateNormal];
    rightButton.backgroundColor = UIColor.whiteColor;
    rightButton.layer.cornerRadius = 5;
    rightButton.layer.shadowOffset = CGSizeMake(0, 1);
    rightButton.layer.shadowOpacity = 0.4;
    rightButton.layer.shadowRadius = 0;
    [rightButton addTarget: self action: @selector(pressRight) forControlEvents: UIControlEventTouchUpInside];
    [self.bar addSubview:rightButton];
    
    UIButton *upButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [upButton.titleLabel setFont:[UIFont systemFontOfSize:24]];
    [upButton setFrame:CGRectMake(185, 0, 31, 43)];
    [upButton setTitle:@"???" forState:UIControlStateNormal];
    upButton.backgroundColor = UIColor.whiteColor;
    upButton.layer.cornerRadius = 5;
    upButton.layer.shadowOffset = CGSizeMake(0, 1);
    upButton.layer.shadowOpacity = 0.4;
    upButton.layer.shadowRadius = 0;
    [upButton addTarget: self action: @selector(pressUp) forControlEvents: UIControlEventTouchUpInside];
    [self.bar addSubview:upButton];
    
    UIButton *downButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [downButton.titleLabel setFont:[UIFont systemFontOfSize:24]];
    [downButton setFrame:CGRectMake(222, 0, 31, 43)];
    [downButton setTitle:@"???" forState:UIControlStateNormal];
    downButton.backgroundColor = UIColor.whiteColor;
    downButton.layer.cornerRadius = 5;
    downButton.layer.shadowOffset = CGSizeMake(0, 1);
    downButton.layer.shadowOpacity = 0.4;
    downButton.layer.shadowRadius = 0;
    [downButton addTarget: self action: @selector(pressDown) forControlEvents: UIControlEventTouchUpInside];
    [self.bar addSubview:downButton];
    
    UIButton *slashButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [slashButton.titleLabel setFont:[UIFont systemFontOfSize:24]];
    [slashButton setFrame:CGRectMake(259, 0, 31, 43)];
    [slashButton setTitle:@"/" forState:UIControlStateNormal];
    slashButton.backgroundColor = UIColor.whiteColor;
    slashButton.layer.cornerRadius = 5;
    slashButton.layer.shadowOffset = CGSizeMake(0, 1);
    slashButton.layer.shadowOpacity = 0.4;
    slashButton.layer.shadowRadius = 0;
    [slashButton addTarget: self action: @selector(pressSlash) forControlEvents: UIControlEventTouchUpInside];
    [self.bar addSubview:slashButton];
    
    UIButton *pipeButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [pipeButton.titleLabel setFont:[UIFont systemFontOfSize:24]];
    [pipeButton setFrame:CGRectMake(296, 0, 31, 43)];
    [pipeButton setTitle:@"|" forState:UIControlStateNormal];
    pipeButton.backgroundColor = UIColor.whiteColor;
    pipeButton.layer.cornerRadius = 5;
    pipeButton.layer.shadowOffset = CGSizeMake(0, 1);
    pipeButton.layer.shadowOpacity = 0.4;
    pipeButton.layer.shadowRadius = 0;
    [pipeButton addTarget: self action: @selector(pressPipe) forControlEvents: UIControlEventTouchUpInside];
    [self.bar addSubview:pipeButton];
    
    [self.pasteButton setTitle:@"P" forState:UIControlStateNormal];
    [self.pasteButton setImage:nil forState:UIControlStateNormal];
    [self.pasteButton.titleLabel setFont:[UIFont systemFontOfSize:24]];
    [self.pasteButton setFrame:CGRectMake(333, 0, 31, 43)];
    self.pasteButton.backgroundColor = UIColor.whiteColor;
    
    [self.hideKeyboardButton setTitle:@"???" forState:UIControlStateNormal];
    [self.hideKeyboardButton setImage:nil forState:UIControlStateNormal];
    [self.hideKeyboardButton.titleLabel setFont:[UIFont systemFontOfSize:24]];
    [self.hideKeyboardButton setFrame:CGRectMake(370, 0, 31, 43)];
    self.hideKeyboardButton.backgroundColor = UIColor.whiteColor;
    
//    UIButton *hyphenButton = [UIButton buttonWithType: UIButtonTypeSystem];
//    [hyphenButton.titleLabel setFont:[UIFont systemFontOfSize:24]];
//    [hyphenButton setFrame:CGRectMake(407, 0, 31, 43)];
//    [hyphenButton setTitle:@"-" forState:UIControlStateNormal];
//    hyphenButton.backgroundColor = UIColor.whiteColor;
//    hyphenButton.layer.cornerRadius = 5;
//    hyphenButton.layer.shadowOffset = CGSizeMake(0, 1);
//    hyphenButton.layer.shadowOpacity = 0.4;
//    hyphenButton.layer.shadowRadius = 0;
//    [hyphenButton addTarget: self action: @selector(pressHyphen) forControlEvents: UIControlEventTouchUpInside];
//    [self.bar addSubview:hyphenButton];
}

- (void)pressLeft{
    [self.termView insertText:[self.terminal arrow:'D']];
}

- (void)pressRight{
    [self.termView insertText:[self.terminal arrow:'C']];
}

- (void)pressUp{
    [self.termView insertText:[self.terminal arrow:'A']];
}

- (void)pressDown{
    [self.termView insertText:[self.terminal arrow:'B']];
}

- (void)pressSlash{
    [self.termView insertText:@"/"];
}

- (void)pressPipe{
    [self.termView insertText:@"|"];
}

- (void)pressHyphen{
    [self.termView insertText:@"-"];
}

- (void)hideKeyboard{
    [self.termView resignFirstResponder];
}

- (void)pressEscape {
    [self.termView insertText:@"\x1b"];
}
- (void)pressTab {
    [self.termView insertText:@"\t"];
}

- (void)pressPaste {
    NSString *string = UIPasteboard.generalPasteboard.string;
    if (string) {
        [self.termView insertText:string];
    }
}

- (void)pressControl {
    self.controlKey.selected = !self.controlKey.selected;
}

- (void)xxx_viewDidLoad {
    [super viewDidLoad];

#if !ISH_LINUX
    int bootError = [AppDelegate bootError];
    if (bootError < 0) {
        NSString *message = [NSString stringWithFormat:@"could not boot"];
        NSString *subtitle = [NSString stringWithFormat:@"error code %d", bootError];
        if (bootError == _EINVAL)
            subtitle = [subtitle stringByAppendingString:@"\n(try reinstalling the app, see release notes for details)"];
        [self showMessage:message subtitle:subtitle];
        NSLog(@"boot failed with code %d", bootError);
    }
#endif

    self.terminal = self.terminal;
    [self.termView becomeFirstResponder];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(keyboardDidSomething:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(keyboardDidSomething:)
                   name:UIKeyboardDidChangeFrameNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(_updateBadge)
                   name:FsUpdatedNotification
                 object:nil];


    [self _updateStyleFromPreferences:NO];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        [self.bar removeArrangedSubview:self.hideKeyboardButton];
        [self.hideKeyboardButton removeFromSuperview];
    }
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        self.barView.frame = CGRectMake(0, 0, 100, 48);
    } else {
        self.barView.frame = CGRectMake(0, 0, 100, 55);
    }
    
    // SF Symbols is cool
    if (@available(iOS 13, *)) {
        [self.infoButton setImage:[UIImage systemImageNamed:@"gear"] forState:UIControlStateNormal];
        [self.pasteButton setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
        [self.hideKeyboardButton setImage:[UIImage systemImageNamed:@"keyboard.chevron.compact.down"] forState:UIControlStateNormal];
        
        [self.tabKey setTitle:nil forState:UIControlStateNormal];
        [self.tabKey setImage:[UIImage systemImageNamed:@"arrow.right.to.line.alt"] forState:UIControlStateNormal];
        [self.controlKey setTitle:nil forState:UIControlStateNormal];
        [self.controlKey setImage:[UIImage systemImageNamed:@"control"] forState:UIControlStateNormal];
        [self.escapeKey setTitle:nil forState:UIControlStateNormal];
        [self.escapeKey setImage:[UIImage systemImageNamed:@"escape"] forState:UIControlStateNormal];
    }
    
    [UserPreferences.shared observe:@[@"hideStatusBar"] options:0 owner:self usingBlock:^(typeof(self) self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNeedsStatusBarAppearanceUpdate];
        });
    }];
    [UserPreferences.shared observe:@[@"colorScheme", @"theme", @"hideExtraKeysWithExternalKeyboard"]
                            options:0 owner:self usingBlock:^(typeof(self) self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _updateStyleFromPreferences:YES];
        });
    }];
    [self _updateBadge];
}

//- (void)awakeFromNib {
//    [super awakeFromNib];
//#if !ISH_LINUX
//    [NSNotificationCenter.defaultCenter addObserver:self
//                                           selector:@selector(processExited:)
//                                               name:ProcessExitedNotification
//                                             object:nil];
//#else
//    [NSNotificationCenter.defaultCenter addObserver:self
//                                           selector:@selector(kernelPanicked:)
//                                               name:KernelPanicNotification
//                                             object:nil];
//#endif
//}

- (void)viewDidAppear:(BOOL)animated {
    [AppDelegate maybePresentStartupMessageOnViewController:self];
    [super viewDidAppear:animated];
}

- (void)startNewSession {
    int err = [self startSession];
    if (err < 0) {
        [self showMessage:@"could not start session"
                 subtitle:[NSString stringWithFormat:@"error code %d", err]];
    }
}

- (void)reconnectSessionFromTerminalUUID:(NSUUID *)uuid {
    self.sessionTerminal = [Terminal terminalWithUUID:uuid];
    if (self.sessionTerminal == nil)
        [self startNewSession];
}

- (NSUUID *)sessionTerminalUUID {
    return self.terminal.uuid;
}

- (int)startSession {
    NSArray<NSString *> *command = UserPreferences.shared.launchCommand;

#if !ISH_LINUX
    int err = become_new_init_child();
    if (err < 0)
        return err;
    struct tty *tty;
    self.sessionTerminal = nil;
    Terminal *terminal = [Terminal createPseudoTerminal:&tty];
    if (terminal == nil) {
        NSAssert(IS_ERR(tty), @"tty should be error");
        return (int) PTR_ERR(tty);
    }
    self.sessionTerminal = terminal;
    NSString *stdioFile = [NSString stringWithFormat:@"/dev/pts/%d", tty->num];
    err = create_stdio(stdioFile.fileSystemRepresentation, TTY_PSEUDO_SLAVE_MAJOR, tty->num);
    if (err < 0)
        return err;
    tty_release(tty);

    char argv[4096];
    [Terminal convertCommand:command toArgs:argv limitSize:sizeof(argv)];
    const char *envp = "TERM=xterm-256color\0";
    err = do_execve(command[0].UTF8String, command.count, argv, envp);
    if (err < 0)
        return err;
    self.sessionPid = current->pid;
    task_start(current);
#else
    const char *argv_arr[command.count + 1];
    for (NSUInteger i = 0; i < command.count; i++)
        argv_arr[i] = command[i].UTF8String;
    argv_arr[command.count] = NULL;
    const char *envp_arr[] = {
        "TERM=xterm-256color",
        NULL,
    };
    const char *const *argv = argv_arr;
    const char *const *envp = envp_arr;
    __block Terminal *terminal = nil;
    __block int sessionPid = 0;
    __block int err = 1;
    sync_do_in_workqueue(^(void (^done)(void)) {
        linux_start_session(argv[0], argv, envp, ^(int retval, int pid, nsobj_t term) {
            err = retval;
            if (term)
                terminal = CFBridgingRelease(term);
            sessionPid = pid;
            done();
        });
    });
    NSAssert(err <= 0, @"session start did not finish??");
    if (err < 0)
        return err;
    self.sessionTerminal = terminal;
    self.sessionPid = sessionPid;
#endif
    return 0;
}

#if !ISH_LINUX
- (void)processExited:(NSNotification *)notif {
    int pid = [notif.userInfo[@"pid"] intValue];
    if (pid != self.sessionPid)
        return;

    [self.sessionTerminal destroy];
    // On iOS 13, there are multiple windows, so just close this one.
    if (@available(iOS 13, *)) {
        // On iPhone, destroying scenes will fail, but the error doesn't actually go to the error handler, which is really stupid. Apple doesn't fix bugs, so I'm forced to just add a check here.
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad && self.sceneSession != nil) {
            [UIApplication.sharedApplication requestSceneSessionDestruction:self.sceneSession options:nil errorHandler:^(NSError *error) {
                NSLog(@"scene destruction error %@", error);
                self.sceneSession = nil;
                [self processExited:notif];
            }];
            return;
        }
    }
    current = NULL; // it's been freed
    [self startNewSession];
}
#endif

#if ISH_LINUX
- (void)kernelPanicked:(NSNotification *)notif {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"panik" message:notif.userInfo[@"message"] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"k" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
#endif

- (void)showMessage:(NSString *)message subtitle:(NSString *)subtitle {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:message message:subtitle preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"k"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [UserPreferences shared]) {
        [self _updateStyleFromPreferences:YES];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)_updateStyleFromPreferences:(BOOL)animated {
    NSAssert(NSThread.isMainThread, @"This method needs to be called on the main thread");
    NSTimeInterval duration = animated ? 0.1 : 0;
    [UIView animateWithDuration:duration animations:^{
        self.view.backgroundColor = [[UIColor alloc] ish_initWithHexString:UserPreferences.shared.palette.backgroundColor];
        UIKeyboardAppearance keyAppearance = UserPreferences.shared.keyboardAppearance;
        self.termView.keyboardAppearance = keyAppearance;
        for (BarButton *button in self.barButtons) {
            button.keyAppearance = keyAppearance;
        }
        UIColor *tintColor = keyAppearance == UIKeyboardAppearanceLight ? UIColor.blackColor : UIColor.whiteColor;
        for (UIControl *control in self.barControls) {
            control.tintColor = tintColor;
        }
    }];
    UIView *oldBarView = self.termView.inputAccessoryView;
    if (UserPreferences.shared.hideExtraKeysWithExternalKeyboard && self.hasExternalKeyboard) {
        self.termView.inputAccessoryView = nil;
    } else {
        self.termView.inputAccessoryView = self.barView;
    }
    if (self.termView.inputAccessoryView != oldBarView && self.termView.isFirstResponder) {
        self.ignoreKeyboardMotion = YES; // avoid infinite recursion
        [self.termView reloadInputViews];
        self.ignoreKeyboardMotion = NO;
    }
}
- (void)_updateStyleAnimated {
    [self _updateStyleFromPreferences:YES];
}

- (void)_updateBadge {
    self.settingsBadge.hidden = !FsNeedsRepositoryUpdate();
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UserPreferences.shared.statusBarStyle;
}

- (BOOL)prefersStatusBarHidden {
    return UserPreferences.shared.hideStatusBar;
}

- (void)keyboardDidSomething:(NSNotification *)notification {
    if (self.ignoreKeyboardMotion)
        return;

    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrame = [self.view convertRect:keyboardFrame fromView:self.view.window];
    if (CGRectEqualToRect(keyboardFrame, CGRectZero))
        return;
//    NSLog(@"%@ %@", notification.name, [NSValue valueWithCGRect:keyboardFrame]);
//    self.hasExternalKeyboard = keyboardFrame.size.height < 100;
    CGFloat pad = self.view.bounds.size.height - keyboardFrame.origin.y;
    
    pad += (UIScreen.mainScreen.bounds.size.height - self.view.frame.size.height) / 2;

    if (pad != keyboardFrame.size.height && keyboardFrame.size.width != UIScreen.mainScreen.bounds.size.width) {
        pad = MAX(self.view.safeAreaInsets.bottom, self.termView.inputAccessoryView.frame.size.height);
    }
    // NSLog(@"pad %f", pad);
    self.bottomConstraint.constant = pad;

    BOOL initialLayout = self.termView.needsUpdateConstraints;
    [self.view setNeedsUpdateConstraints];
    if (!initialLayout) {
        // if initial layout hasn't happened yet, the terminal view is going to be at a really weird place, so animating it is going to look really bad
        NSNumber *interval = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
        NSNumber *curve = notification.userInfo[UIKeyboardAnimationCurveUserInfoKey];
        [UIView animateWithDuration:interval.doubleValue
                              delay:0
                            options:curve.integerValue << 16
                         animations:^{
                             [self.view layoutIfNeeded];
                         }
                         completion:nil];
    }
}

- (void)xxx_keyboardDidSomething:(NSNotification *)notification {
    if (self.ignoreKeyboardMotion)
        return;

    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrame = [self.view convertRect:keyboardFrame fromView:self.view.window];
    if (CGRectEqualToRect(keyboardFrame, CGRectZero))
        return;
    NSLog(@"%@ %@", notification.name, [NSValue valueWithCGRect:keyboardFrame]);
    self.hasExternalKeyboard = keyboardFrame.size.height < 100;
    CGFloat pad = self.view.bounds.size.height - keyboardFrame.origin.y;
    // In Slide Over, we get a keyboard frame that is in screen coordinates but
    // the app is slightly shorter than the screen height. Try to determine the
    // screen position by assuming the app is vertically centered, then
    // correcting for the difference.
    pad += (UIScreen.mainScreen.bounds.size.height - self.view.frame.size.height) / 2;
    // The keyboard appears to be undocked. This means it can either be split or
    // truly floating. In the former case we want to keep the pad, but in the
    // latter we should fall back to the input accessory view instead of the
    // keyboard.
    if (pad != keyboardFrame.size.height && keyboardFrame.size.width != UIScreen.mainScreen.bounds.size.width) {
        pad = MAX(self.view.safeAreaInsets.bottom, self.termView.inputAccessoryView.frame.size.height);
    }
    // NSLog(@"pad %f", pad);
    self.bottomConstraint.constant = pad;

    BOOL initialLayout = self.termView.needsUpdateConstraints;
    [self.view setNeedsUpdateConstraints];
    if (!initialLayout) {
        // if initial layout hasn't happened yet, the terminal view is going to be at a really weird place, so animating it is going to look really bad
        NSNumber *interval = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
        NSNumber *curve = notification.userInfo[UIKeyboardAnimationCurveUserInfoKey];
        [UIView animateWithDuration:interval.doubleValue
                              delay:0
                            options:curve.integerValue << 16
                         animations:^{
                             [self.view layoutIfNeeded];
                         }
                         completion:nil];
    }
}

- (void)setHasExternalKeyboard:(BOOL)hasExternalKeyboard {
    _hasExternalKeyboard = hasExternalKeyboard;
    [self _updateStyleFromPreferences:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"embed"]) {
        // You might want to check if this is your embed segue here
        // in case there are other segues triggered from this view controller.
        segue.destinationViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    // Hack to resolve a layering mismatch between the the UI and preferences.
    if (@available(iOS 12.0, *)) {
        if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
            // Ensure that the relevant things listening for this will update.
            UserPreferences.shared.colorScheme = UserPreferences.shared.colorScheme;
        }
    }
}

#pragma mark Bar

- (IBAction)showAbout:(id)sender {
    UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"About" bundle:nil] instantiateInitialViewController];
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *recognizer = sender;
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            AboutViewController *aboutViewController = (AboutViewController *) navigationController.topViewController;
            aboutViewController.includeDebugPanel = YES;
        } else {
            return;
        }
    }
    [self presentViewController:navigationController animated:YES completion:nil];
    [self.termView resignFirstResponder];
}

- (void)resizeBar {
    CGSize screen = UIScreen.mainScreen.bounds.size;
    CGSize bar = self.barView.bounds.size;
    // set sizing parameters on bar
    // numbers stolen from iVim and modified somewhat
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        // phone
        [self setBarHorizontalPadding:6 verticalPadding:6 buttonWidth:32];
    } else if (bar.width == screen.width || bar.width == screen.height) {
        // full-screen ipad
        [self setBarHorizontalPadding:15 verticalPadding:8 buttonWidth:43];
    } else if (bar.width <= 320) {
        // slide over
        [self setBarHorizontalPadding:8 verticalPadding:8 buttonWidth:26];
    } else {
        // split view
        [self setBarHorizontalPadding:10 verticalPadding:8 buttonWidth:36];
    }
    [UIView performWithoutAnimation:^{
        [self.barView layoutIfNeeded];
    }];
}

- (void)setBarHorizontalPadding:(CGFloat)horizontal verticalPadding:(CGFloat)vertical buttonWidth:(CGFloat)buttonWidth {
    self.barLeading.constant = self.barTrailing.constant = horizontal;
    self.barTop.constant = self.barBottom.constant = vertical;
    self.barButtonWidth.constant = buttonWidth;
}

- (IBAction)pressEscape:(id)sender {
    [self pressKey:@"\x1b"];
}
- (IBAction)pressTab:(id)sender {
    [self pressKey:@"\t"];
}
- (void)pressKey:(NSString *)key {
    [self.termView insertText:key];
}

- (IBAction)pressControl:(id)sender {
    self.controlKey.selected = !self.controlKey.selected;
}
    
- (IBAction)pressArrow:(ArrowBarButton *)sender {
    switch (sender.direction) {
        case ArrowUp: [self pressKey:[self.terminal arrow:'A']]; break;
        case ArrowDown: [self pressKey:[self.terminal arrow:'B']]; break;
        case ArrowLeft: [self pressKey:[self.terminal arrow:'D']]; break;
        case ArrowRight: [self pressKey:[self.terminal arrow:'C']]; break;
        case ArrowNone: break;
    }
}

- (void)switchTerminal:(UIKeyCommand *)sender {
    unsigned i = (unsigned) sender.input.integerValue;
    if (i == 7)
        self.terminal = self.sessionTerminal;
    else
        self.terminal = [Terminal terminalWithType:TTY_CONSOLE_MAJOR number:i];
}

- (void)increaseFontSize:(UIKeyCommand *)command {
    self.termView.overrideFontSize = self.termView.effectiveFontSize + 1;
}
- (void)decreaseFontSize:(UIKeyCommand *)command {
    self.termView.overrideFontSize = self.termView.effectiveFontSize - 1;
}
- (void)resetFontSize:(UIKeyCommand *)command {
    self.termView.overrideFontSize = 0;
}

- (NSArray<UIKeyCommand *> *)keyCommands {
    static NSMutableArray<UIKeyCommand *> *commands = nil;
    if (commands == nil) {
        commands = [NSMutableArray new];
        for (unsigned i = 1; i <= 7; i++) {
            [commands addObject:
             [UIKeyCommand keyCommandWithInput:[NSString stringWithFormat:@"%d", i]
                                 modifierFlags:UIKeyModifierCommand|UIKeyModifierAlternate|UIKeyModifierShift
                                        action:@selector(switchTerminal:)]];
        }
        [commands addObject:
         [UIKeyCommand keyCommandWithInput:@"+"
                             modifierFlags:UIKeyModifierCommand
                                    action:@selector(increaseFontSize:)
                      discoverabilityTitle:@"Increase Font Size"]];
        [commands addObject:
         [UIKeyCommand keyCommandWithInput:@"="
                             modifierFlags:UIKeyModifierCommand
                                    action:@selector(increaseFontSize:)]];
        [commands addObject:
         [UIKeyCommand keyCommandWithInput:@"-"
                             modifierFlags:UIKeyModifierCommand
                                    action:@selector(decreaseFontSize:)
                      discoverabilityTitle:@"Decrease Font Size"]];
        [commands addObject:
         [UIKeyCommand keyCommandWithInput:@"0"
                             modifierFlags:UIKeyModifierCommand
                                    action:@selector(resetFontSize:)
                      discoverabilityTitle:@"Reset Font Size"]];
        [commands addObject:
         [UIKeyCommand keyCommandWithInput:@","
                             modifierFlags:UIKeyModifierCommand
                                    action:@selector(showAbout:)
                      discoverabilityTitle:@"Settings"]];
    }
    return commands;
}

- (void)setTerminal:(Terminal *)terminal {
    _terminal = terminal;
    self.termView.terminal = self.terminal;
}

- (void)setSessionTerminal:(Terminal *)sessionTerminal {
    if (_terminal == _sessionTerminal)
        self.terminal = sessionTerminal;
    _sessionTerminal = sessionTerminal;
}

@end

@interface BarView : UIInputView
@property (weak) IBOutlet TerminalViewController *terminalViewController;
@property (nonatomic) IBInspectable BOOL allowsSelfSizing;
@end
@implementation BarView
@dynamic allowsSelfSizing;

- (void)layoutSubviews {
    [self.terminalViewController resizeBar];
}

@end
