#import "Tweak.h"
#import "CantReachMe/WDFReachabilityController.h"

static bool wdfTweakEnabled;
static NSString *wdfAction;

BOOL isSpringboard;
BOOL performAction = YES;
WDFReachabilityController *wdfReachabilityController;

%group CantReachMe
%hook SBReachabilityManager
-(void)_activateReachability:(id)arg1 {
    NSLog(@"_activateReachability");
    if(wdfTweakEnabled) {
        if(performAction)
            [self wdfPerformReachabilityAction];
        performAction = !performAction;
    } else {
        %orig;
    }
}

-(void)toggleReachability {
    NSLog(@"toggleReachability");
    if(wdfTweakEnabled)
        [self wdfPerformReachabilityAction];
    else
        %orig;
}

%new
-(void)wdfPerformReachabilityAction {
    NSLog(@"wdfPerformReachabilityAction");
    //runStrategyForAction(wdfAction, wdfReachabilityController);
    [wdfReachabilityController runStrategyForAction:wdfAction];
}
%end
%end // group CantReachMe

void wdfReloadPrefs() {
    NSDictionary *bundleDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"0xcc.woodfairy.cantreachme"];
    id isEnabled                 = [bundleDefaults valueForKey:@"Enabled"];
    wdfTweakEnabled              = isEnabled ? [isEnabled boolValue] : YES;
    wdfAction                    = [bundleDefaults valueForKey:@"crm_action"] ?: @"coversheet";
}

%ctor {
    NSArray *blacklist = @[
        @"backboardd",
        @"duetexpertd",
        @"lsd",
        @"nsurlsessiond",
        @"assertiond",
        @"ScreenshotServicesService",
        @"com.apple.datamigrator",
        @"CircleJoinRequested",
        @"nanotimekitcompaniond",
        @"ReportCrash",
        @"ptpd"
    ];

    NSString *processName = [NSProcessInfo processInfo].processName;

    for (NSString *process in blacklist) {
        if ([process isEqualToString:processName])
            return;
    }

    isSpringboard = [@"SpringBoard" isEqualToString:processName];

    // I have taken this code from Nepetas SwipeShot
    // Someone smarter than me invented this.
    // https://www.reddit.com/r/jailbreak/comments/4yz5v5/questionremote_messages_not_enabling/d6rlh88/
    bool shouldLoad = NO;
    NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
    NSUInteger count = args.count;
    if (count != 0) {
        NSString *executablePath  = args[0];
        if (executablePath) {
            NSString *processName = [executablePath lastPathComponent];
            BOOL isApplication    = [executablePath rangeOfString:@"/Application/"].location != NSNotFound || [executablePath rangeOfString:@"/Applications/"].location != NSNotFound;
            BOOL isFileProvider   = [[processName lowercaseString] rangeOfString:@"fileprovider"].location != NSNotFound;
            BOOL skip = [processName isEqualToString:@"AdSheet"]
                        || [processName isEqualToString:@"CoreAuthUI"]
                        || [processName isEqualToString:@"InCallService"]
                        || [processName isEqualToString:@"MessagesNotificationViewService"]
                        || [executablePath rangeOfString:@".appex/"].location != NSNotFound;
            if ((!isFileProvider && isApplication && !skip) || isSpringboard)
                shouldLoad = YES;
        }
    }

    if (!shouldLoad) return;
    wdfReachabilityController = [[WDFReachabilityController alloc] init];
    wdfReloadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, wdfReloadPrefs, CFSTR("0xcc.woodfairy.cantreachme/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    %init(CantReachMe)
}
