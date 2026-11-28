#import "../timer-lifecycle.h"
#import "Shared/Player/PlayerState.h"
#import "Core/SGRebind.h"
#import <dns_sd.h>

static NSUInteger searches, stops;
BOOL SGRebindImport(const char *name, void *replacement, void **original) { return NO; }
#import "Connect.m"

@protocol LocationObserver <NSObject>
- (void)aggregator:(id)aggregator didUpdateAggregatorState:(id)state;
@end
@interface _TtC22Connect_AggregatorImpl24ConnectAggregatorManager : NSObject
@property (nonatomic, getter=isPlayingLocally) BOOL local;
@property (nonatomic, strong) NSMutableArray *observers;
- (void)addStateObserver:(id)observer;
- (void)report;
@end
@implementation _TtC22Connect_AggregatorImpl24ConnectAggregatorManager
- (void)addStateObserver:(id)observer {
    if (!_observers) _observers = [NSMutableArray array];
    [_observers addObject:observer];
}
- (void)report {
    for (id<LocationObserver> observer in _observers)
        if ([observer respondsToSelector:@selector(aggregator:didUpdateAggregatorState:)])
            [observer aggregator:self didUpdateAggregatorState:nil];
}
@end

static void drainLocation(void) {
    // Manager attachment queues its initial location report on the next main-queue turn.
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_main_queue(), ^{ CFRunLoopStop(CFRunLoopGetMain()); });
    });
    CFRunLoopRun();
}

@interface SPTEsperantoPlayer : NSObject
@property (nonatomic) BOOL watched;
@end
@implementation SPTEsperantoPlayer
- (void)addPlayerObserver:(id)observer {
    if ([observer respondsToSelector:@selector(player:stateDidChange:)]) self.watched = YES;
}
@end

static void checkPlayerSelection(void) {
    NSArray *players = @[[SPTEsperantoPlayer new], [SPTEsperantoPlayer new]];
    dispatch_apply(players.count, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t i) {
        [players[i] addPlayerObserver:[NSObject new]];
    });
    drainLocation();
    HARNESS_CHECK(SGPlayerInstance() == SGPlayer() && [SGPlayer() watched]);
    HARNESS_CHECK([players[0] watched] != [players[1] watched]);
}

int main(void) {
    @autoreleasepool {
        @autoreleasepool { checkPlayerSelection(); }
        // With the first weak player gone, the next winner needs an observer too.
        checkPlayerSelection();
        SGHarnessBeginTimerCapture();
        Method search = class_getInstanceMethod(NSNetServiceBrowser.class, @selector(searchForServicesOfType:inDomain:));
        Method stop = class_getInstanceMethod(NSNetServiceBrowser.class, @selector(stop));
        Method resolve = class_getInstanceMethod(NSNetService.class, @selector(resolveWithTimeout:));
        IMP oldSearch = method_setImplementation(search, imp_implementationWithBlock(^(id object, NSString *type, NSString *domain) { searches++; }));
        IMP oldStop = method_setImplementation(stop, imp_implementationWithBlock(^(id object) { stops++; }));
        IMP oldResolve = method_setImplementation(resolve, imp_implementationWithBlock(^(id object, NSTimeInterval timeout) {}));
        SGConnectBrowser *browser = [SGConnectBrowser new];
        [browser start];
        HARNESS_CHECK(searches == 1);
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
        HARNESS_CHECK(stops == 1 && SGHarnessLiveTimers() == 0);
        NSObject *first = [NSObject new], *second = [NSObject new];
        pickerVisible(first, YES);
        pickerVisible(second, YES);
        HARNESS_CHECK(searches == 2);
        pickerVisible(first, NO);
        HARNESS_CHECK(stops == 1);
        pickerVisible(second, NO);
        HARNESS_CHECK(stops == 2);
        __block NSUInteger notices = 0;
        id token = [NSNotificationCenter.defaultCenter addObserverForName:SGPlayerPlaybackLocationDidChangeNotification
            object:nil queue:nil usingBlock:^(NSNotification *note) {
                HARNESS_CHECK(NSThread.isMainThread);
                notices++;
            }];
        HARNESS_CHECK(!SGPlayerPlaybackIsLocal() && !SGPlayerPlaybackIsRemote());
        _TtC22Connect_AggregatorImpl24ConnectAggregatorManager *manager =
            [_TtC22Connect_AggregatorImpl24ConnectAggregatorManager new];
        dispatch_sync(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            [manager addStateObserver:[NSObject new]];
        });
        drainLocation();
        HARNESS_CHECK(searches == 3 && notices == 1 && SGPlayerPlaybackIsRemote() && !SGPlayerPlaybackIsLocal());
        [manager report];
        drainLocation();
        HARNESS_CHECK(notices == 1);
        manager.local = YES;
        [manager report];
        drainLocation();
        HARNESS_CHECK(notices == 2 && stops == 3 && SGPlayerPlaybackIsLocal() && !SGPlayerPlaybackIsRemote());
        manager.local = NO;
        dispatch_sync(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [manager report]; });
        drainLocation();
        HARNESS_CHECK(notices == 3 && searches == 4 && SGPlayerPlaybackIsRemote());
        NSNetServiceBrowser *service = [browser valueForKey:@"browser"];
        [browser netServiceBrowser:service didNotSearch:@{NSNetServicesErrorCode: @(kDNSServiceErr_PolicyDenied)}];
        [browser update];
        HARNESS_CHECK(searches == 4 && SGHarnessLiveTimers() == 0);
        [browser foreground];
        HARNESS_CHECK(searches == 5);
        manager.local = YES;
        [manager report];
        drainLocation();
        [browser background];
        [browser foreground];
        HARNESS_CHECK(searches == 6);
        // Repeated non-policy browse failures double up to kLastBrowseRetry instead of looping every 3 s.
        NSDictionary *transient = @{NSNetServicesErrorCode: @(NSNetServicesUnknownError)};
        NSTimeInterval (^triggerFail)(void) = ^NSTimeInterval {
            NSNetServiceBrowser *active = [browser valueForKey:@"browser"];
            HARNESS_CHECK(active != nil);
            NSDate *start = NSDate.date;
            [browser netServiceBrowser:active didNotSearch:transient];
            HARNESS_CHECK(SGHarnessLiveTimers() == 1);
            NSTimer *retry = sg_testTimers.lastObject;
            HARNESS_CHECK(retry.valid);
            return [retry.fireDate timeIntervalSinceDate:start];
        };
        const NSTimeInterval expectedDelays[] = {3, 6, 12, 24, 48, 60, 60};
        for (size_t i = 0; i < sizeof(expectedDelays) / sizeof(expectedDelays[0]); i++) {
            NSTimeInterval delay = triggerFail();
            HARNESS_CHECK(fabs(delay - expectedDelays[i]) < 0.5);
            NSUInteger before = searches;
            [sg_testTimers.lastObject fire];
            HARNESS_CHECK(SGHarnessLiveTimers() == 0 && searches == before + 1);
        }
        // Finding a service resets the backoff to kBrowseRetry.
        NSNetService *found = [[NSNetService alloc] initWithDomain:@"local." type:@"_spotify-connect._tcp." name:@"speaker"];
        [browser netServiceBrowser:[browser valueForKey:@"browser"] didFindService:found moreComing:NO];
        HARNESS_CHECK(fabs(triggerFail() - 3) < 0.5);
        [sg_testTimers.lastObject fire];
        HARNESS_CHECK(fabs(triggerFail() - 6) < 0.5);
        // A network path change cancels a pending backoff timer and retries immediately from 3 s.
        NSUInteger beforePath = searches;
        [browser pathChanged];
        HARNESS_CHECK(SGHarnessLiveTimers() == 0 && searches == beforePath + 1);
        HARNESS_CHECK(fabs(triggerFail() - 3) < 0.5);
        [sg_testTimers.lastObject fire];
        HARNESS_CHECK(fabs(triggerFail() - 6) < 0.5);
        // Opening the device picker during backoff retries immediately and resets the delay.
        NSUInteger beforePicker = searches;
        pickerVisible(first, YES);
        HARNESS_CHECK(SGHarnessLiveTimers() == 0 && searches == beforePicker + 1);
        pickerVisible(first, NO);
        HARNESS_CHECK(fabs(triggerFail() - 3) < 0.5);
        // Background remote playback backs off too, and returning to local playback cancels and resets it.
        manager.local = NO;
        [manager report];
        drainLocation();
        [browser background];
        [sg_testTimers.lastObject fire];
        HARNESS_CHECK(fabs(triggerFail() - 6) < 0.5);
        manager.local = YES;
        [manager report];
        drainLocation();
        HARNESS_CHECK(SGHarnessLiveTimers() == 0);
        [browser foreground];
        HARNESS_CHECK(fabs(triggerFail() - 3) < 0.5);
        [browser background];
        HARNESS_CHECK(SGHarnessLiveTimers() == 0);
        method_setImplementation(search, oldSearch);
        method_setImplementation(stop, oldStop);
        method_setImplementation(resolve, oldResolve);
        [NSNotificationCenter.defaultCenter removeObserver:token];
        SGHarnessEndTimerCapture();
        puts("PASS Connect background, initial remote attachment, deduplicated main-thread location changes, picker, denial and browse backoff lifecycle");
    }
}
