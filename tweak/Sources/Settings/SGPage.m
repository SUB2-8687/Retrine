#import "SGPage.h"
#import "SGPageStyle.h"
#import "Core/SGCore.h"
#import <objc/runtime.h>
#import "../../../NativeDownloads/src/UI/PixiePageNavigation.h"


// Spotify's navigation controller asserts that everything on its stack is one of its own pages
// (SPNavigationController.m:645, "[viewController conformsToProtocol:@protocol(SPTPageController)]"),
// and the tab bar asks it for that page on every tab tap to log the interaction. A plain view
// controller of the mod's pushed onto that stack therefore takes the app down the next time a tab
// is pressed, from wherever it was left. The pages below answer the protocol's two questions
// instead and are registered as conforming at load; if the protocol is gone they are presented
// rather than pushed, so a rename in some later Spotify costs the push, not the app.

@implementation SGPage {
    NSTimer *_refreshTimer;
    BOOL _refreshVisible, _refreshActive;
}

// Inset grouped cards on black, the way Settings draws them, a hairline between the rows of a card.
- (void)viewDidLoad {
    [super viewDidLoad];
    _refreshActive = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(refreshResigned) name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(refreshBecameActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.tableView.backgroundColor = SGPageBackground();
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.1];
    self.tableView.sectionHeaderTopPadding = 0;
}

- (void)updateRefreshTimer {
    [_refreshTimer invalidate];
    _refreshTimer = nil;
    if (!_refreshVisible || !_refreshActive || !_refreshSelector) return;
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:_refreshSelector userInfo:nil repeats:YES];
}

- (void)setRefreshSelector:(SEL)selector {
    _refreshSelector = selector;
    [self updateRefreshTimer];
}

- (void)refreshResigned {
    // WillResignActive precedes UIApplication's state change.
    _refreshActive = NO;
    [self updateRefreshTimer];
}

- (void)refreshBecameActive {
    _refreshActive = YES;
    [self updateRefreshTimer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _refreshVisible = YES;
    [self updateRefreshTimer];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    _refreshVisible = NO;
    [self updateRefreshTimer];
}

- (void)dealloc {
    [_refreshTimer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if (![previous.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory])
        [self.tableView reloadData];
}

- (NSString *)spt_pageIdentifier {
    return @"spotifyglass";
}

- (NSURL *)spt_pageURI {
    return [NSURL URLWithString:@"spotify:internal:spotifyglass"];
}

@end

void SGRegisterPages(void) {
    if (!SAPSpotifyPageContract(SGPage.class, YES)) SGLog(@"SPTPageController unavailable or incompatible; presenting mod pages");
}

static const void *kRebuildKey = &kRebuildKey;

void SGSetPageRebuild(UIViewController *page, UIViewController *(^rebuild)(void)) {
    objc_setAssociatedObject(page, kRebuildKey, rebuild, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

void SGShowPageBuilt(UIViewController *owner, UIViewController *(^build)(void)) {
    UIViewController *page = build();
    SGSetPageRebuild(page, build);
    SGShowPage(owner, page);
}

void SGPushPageBuilt(UINavigationController *navigation, UIViewController *(^build)(void)) {
    UIViewController *page = build();
    SGSetPageRebuild(page, build);
    if (!page || !navigation) return;
    // As SGShowPage does: a stack that cannot take the page gets it presented on a stack of its own.
    if (SAPCanPushPage(navigation, page)) [navigation pushViewController:page animated:YES];
    else {
        UINavigationController *nav = SAPFallbackPageStack(page);
        SGPresentDark(nav);
        [navigation presentViewController:nav animated:YES completion:nil];
    }
}

void SGRebuildPagesForLanguage(UINavigationController *navigation) {
    if (!navigation) return;
    NSMutableArray<UIViewController *> *pages = [navigation.viewControllers mutableCopy];
    BOOL replaced = NO;
    for (NSUInteger i = 0; i < pages.count; i++) {
        UIViewController *old = pages[i];
        UIViewController *(^rebuild)(void) = objc_getAssociatedObject(old, kRebuildKey);
        // A page that already re-reads its words when the language changes keeps what the person typed into it.
        if (!rebuild || [old respondsToSelector:@selector(languageDidChange:)]) continue;
        UIViewController *fresh = rebuild();
        if (!fresh) continue;
        SGSetPageRebuild(fresh, rebuild);
        CGPoint offset = CGPointZero;
        BOOL keepsOffset = [old isKindOfClass:UITableViewController.class] && old.isViewLoaded;
        if (keepsOffset) offset = ((UITableViewController *)old).tableView.contentOffset;
        pages[i] = fresh;
        replaced = YES;
        if (keepsOffset && [fresh isKindOfClass:UITableViewController.class]) {
            UITableView *table = ((UITableViewController *)fresh).tableView;
            CGPoint kept = offset;
            dispatch_async(dispatch_get_main_queue(), ^{ [table setContentOffset:kept animated:NO]; });
        }
    }
    if (replaced) [navigation setViewControllers:pages animated:NO];
}

void SGShowPage(UIViewController *owner, UIViewController *page) {
    if (!page) return;
    if (SAPCanPushPage(owner.navigationController,page)) [owner.navigationController pushViewController:page animated:YES];
    else {
        UINavigationController *nav = SAPFallbackPageStack(page);
        SGPresentDark(nav);
        [owner presentViewController:nav animated:YES completion:nil];
    }
}
