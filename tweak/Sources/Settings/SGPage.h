// The base of every page of the mod's, pushable onto Spotify's own navigation stack.
#import <UIKit/UIKit.h>

@interface SGPage : UITableViewController
// Once a second while this page is visible and the app active; nil for a static page.
@property (nonatomic) SEL refreshSelector;
@end

// Registers SGPage as one of Spotify's pages; called once, from the settings hook's %ctor.
void SGRegisterPages(void);
// Pushes the page if it can go on Spotify's stack, presents it otherwise.
void SGShowPage(UIViewController *owner, UIViewController *page);
// A page remembers how it was built, so a change of the mod's language can build it again in the new one. Every page a
// row opens, and every page SGShowPageBuilt / SGPushPageBuilt puts up, is registered this way.
void SGSetPageRebuild(UIViewController *page, UIViewController *(^rebuild)(void));
// Shows or pushes the page `build` makes and registers `build` as its way to be made again.
void SGShowPageBuilt(UIViewController *owner, UIViewController *(^build)(void));
void SGPushPageBuilt(UINavigationController *navigation, UIViewController *(^build)(void));
// After the language changed: every page on the stack that has a way to be built again is replaced by a fresh one, in
// place and without animation, keeping its scroll position. A page that follows the change itself (it answers
// -languageDidChange:) stays as it is. Nothing restarts and the stack keeps its order.
void SGRebuildPagesForLanguage(UINavigationController *navigation);
// Mod Settings, pushed onto the selected tab's stack; `source` is any view on the tab bar.
void SGOpenModSettings(UIView *source);
