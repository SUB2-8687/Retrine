// Spotify's Data Saver and Offline page (what Mod › Storage opens, spotify:config:storage) set in Retrine's
// type: 13pt white titles over 11pt gray subtitles, 11pt gray section headers, switches and sliders in the look's
// accent, on black. Spotify's rows, values, switches and buttons stay as they are; only how the text and the
// controls are drawn changes.
//
// The page is one of Spotify's settings lists inside the page wrapper that every pushed page gets (see
// App/ModSettings.x), so it is found by its title, and its views and the list's are what count as the page.
// Spotify sets a label's font, color and text again whenever it reuses a row, so the labels are styled where
// they are set, not once when the page opens: a row that scrolls in later reads as the rows around it.
// What a label is follows from its size and color, which Retrine's own sizes and colors keep, so styling a label
// twice changes nothing: 18pt and up is a section header, 11.5pt and under a subtitle, and between the two a
// muted gray is a subtitle (a menu's description, which Spotify sets nearly as large as its title) and white,
// or a color with a hue, a title.
//
// The page is the same Settings_PlatformImpl list under both looks, so this file runs under both, unlike the
// rest of Native/ (it has no %ctor gate on purpose): the redesign's bold section headers get the same type.
// Spotify's own words on the page follow the mod's language too: Spotify draws them in the app's language, so
// with the mod set to English a Korean page is read word by word through the table below (SGStorageEnglish).
#import <objc/runtime.h>
#import "Core/SGCore.h"
#import "Core/SGLocalize.h"
#import "Settings/SGPageStyle.h"

typedef NS_ENUM(NSInteger, SGStorageRole) { SGStorageTitle, SGStorageSubtitle, SGStorageHeader };

// The page's views, weakly: the wrapper that was pushed and the lists inside it.
static NSHashTable<UIView *> *sg_storageViews;
static BOOL sg_storageClaimed;
// Our own writes go through the hooks below and are left alone there.
static BOOL sg_storageApplying;

// Mod › Storage (App/About/AboutSettings.m) posts this just before it opens spotify:config:storage. Spotify can
// set the page's title after its list has loaded, so for a few seconds after the request the first settings
// list that loads without any title is this page, and it is set in Retrine's type from the start.
static NSString *const kStoragePageRequested = @"SGStoragePageRequested";
static NSTimeInterval sg_storageRequestedAt;
static BOOL SGStorageRequested(void) {
    return sg_storageRequestedAt > 0 && [NSDate timeIntervalSinceReferenceDate] - sg_storageRequestedAt < 5;
}

static BOOL SGIsDataSaverTitle(NSString *title) {
    if (![title isKindOfClass:NSString.class]) return NO;
    NSString *folded = title.lowercaseString;
    return ([folded containsString:@"data"] && [folded containsString:@"offline"]) ||
           ([title containsString:@"데이터"] && [title containsString:@"오프라인"]);
}

static BOOL SGIsDataSaverPage(UIViewController *controller) {
    return SGIsDataSaverTitle(controller.navigationItem.title ?: controller.title);
}

static void SGClaimStorageController(UIViewController *controller) {
    if (!controller.isViewLoaded) return;
    if (!sg_storageViews) sg_storageViews = [NSHashTable weakObjectsHashTable];
    [sg_storageViews addObject:controller.view];
    sg_storageClaimed = YES;
    for (UIViewController *child in controller.childViewControllers) SGClaimStorageController(child);
}

static BOOL SGOnStoragePage(UIView *view) {
    if (!sg_storageClaimed || sg_storageApplying || !view || ![NSThread isMainThread]) return NO;
    for (UIView *root in sg_storageViews) {
        if (view == root || [view isDescendantOfView:root]) return YES;
    }
    return NO;
}

// How bright a neutral gray or white reads, its brightness times its alpha; -1 for a color with a hue, such as
// the green of an accent or a destructive red, which keeps its own.
static CGFloat SGNeutralLevel(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0, a = 0, white = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        if (![color getWhite:&white alpha:&a]) return -1;
        r = g = b = white;
    }
    if (MAX(r, MAX(g, b)) - MIN(r, MIN(g, b)) > 0.12) return -1;
    return (r + g + b) / 3 * a;
}

static SGStorageRole SGRoleFor(UIFont *font, UIColor *color) {
    CGFloat unit = font.pointSize / MAX(SGTitleFont().pointSize / 13.0, 0.5);
    if (unit >= 18) return SGStorageHeader;
    if (unit <= 11.5) return SGStorageSubtitle;
    // A description is a muted gray whatever its size, and a title is white; a text dimmed to almost nothing
    // (a disabled title) is below the gray's range and stays a title in the title's size.
    CGFloat level = color ? SGNeutralLevel(color) : -1;
    return level >= 0.45 && level < 0.85 ? SGStorageSubtitle : SGStorageTitle;
}

static UIFont *SGMappedFont(UIFont *font, SGStorageRole role) {
    UIFont *base = role == SGStorageTitle ? SGTitleFont() : SGSubtitleFont();
    if (role == SGStorageHeader || !(font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold)) return base;
    UIFontDescriptor *bold = [base.fontDescriptor fontDescriptorWithSymbolicTraits:
        base.fontDescriptor.symbolicTraits | UIFontDescriptorTraitBold];
    return bold ? [UIFont fontWithDescriptor:bold size:base.pointSize] : base;
}

// Titles are white and the rest Retrine's gray; a dimmed (disabled) text and a color with a hue stay as they are.
static UIColor *SGMappedColor(UIColor *color, SGStorageRole role) {
    CGFloat level = SGNeutralLevel(color);
    if (level < 0) return color;
    if (role == SGStorageTitle) return level >= 0.85 ? UIColor.whiteColor : color;
    return level >= 0.3 ? SGGrey() : color;
}

static NSAttributedString *SGMappedText(NSAttributedString *text, UIFont *fallback) {
    NSMutableAttributedString *mapped = [text mutableCopy];
    [text enumerateAttributesInRange:NSMakeRange(0, text.length) options:0
                          usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attributes, NSRange range, BOOL *stop) {
        UIFont *font = attributes[NSFontAttributeName] ?: fallback;
        UIColor *color = attributes[NSForegroundColorAttributeName];
        SGStorageRole role = SGRoleFor(font, color);
        [mapped addAttribute:NSFontAttributeName value:SGMappedFont(font, role) range:range];
        if ([color isKindOfClass:UIColor.class]) {
            [mapped addAttribute:NSForegroundColorAttributeName value:SGMappedColor(color, role) range:range];
        }
    }];
    return mapped;
}

// Spotify's own Korean wording on this page and the English it is shown in when the mod's language is English.
// A label is matched whole (a legend's "name | size" by its name), so a word inside a longer text is never cut.
static NSDictionary<NSString *, NSString *> *SGStorageEnglish(void) {
    static NSDictionary *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @{
            @"데이터 절약 및 오프라인": @"Data Saver and Offline",
            @"데이터 세이버 모드": @"Data Saver",
            @"설정을 켜면 스트리밍 품질이 저하되고 동영상 미리보기 등 데이터를 많이 사용하는 기능들이 비활성화됩니다.":
                @"Turning this on lowers streaming quality and turns off features that use a lot of data, such as video previews.",
            @"항상 켜기": @"Always on",
            @"자동": @"Automatic",
            @"iOS 저데이터 모드가 설정되거나 연결 속도가 느려지면 자동으로 켜집니다.":
                @"Turns on automatically when iOS Low Data Mode is set or your connection is slow.",
            @"항상 끄기": @"Always off",
            @"오프라인": @"Offline",
            @"오프라인 모드": @"Offline mode",
            @"인터넷 액세스를 비활성화하여 데이터 소비량을 제한합니다.": @"Turns off internet access to limit data usage.",
            @"다운로드 항목 및 스트리밍": @"Downloads and streaming",
            @"모바일 데이터로 다운로드": @"Download using mobile data",
            @"Wi-Fi에 연결되어 있지 않아도 다운로드가 시작되거나 계속되지만, 기기가 2분 이상 동작하지 않을 경우 다운로드가 일시 정지됩니다.":
                @"Downloads start or continue without Wi-Fi, but pause if the device is idle for more than 2 minutes.",
            @"동영상 팟캐스트의 오디오만 다운로드": @"Download only the audio of video podcasts",
            @"동영상 팟캐스트를 다운로드할 때 오디오만 저장합니다.": @"Saves only the audio when you download a video podcast.",
            @"동영상 팟캐스트의 오디오만 스트리밍": @"Stream only the audio of video podcasts",
            @"Wi-Fi에 연결되지 않은 경우 동영상 팟캐스트의 오디오만 재생합니다.":
                @"Plays only the audio of video podcasts when you are not on Wi-Fi.",
            @"Spotify 앱이 백그라운드에서 실행되는 경우 동영상을 스트리밍하지 않습니다.":
                @"Video is not streamed while the Spotify app runs in the background.",
            @"저장 공간": @"Storage",
            @"저장 공간 상황": @"Storage status",
            @"기타 앱": @"Other apps",
            @"Spotify 다운로드 항목": @"Spotify downloads",
            @"Spotify 캐시": @"Spotify cache",
            @"사용 가능": @"Available",
            @"다운로드한 항목 모두 삭제": @"Delete all downloads",
            @"다운로드한 모든 Spotify 콘텐츠를 삭제해 저장 공간을 확보하세요.": @"Delete all downloaded Spotify content to free up storage.",
            @"삭제하기": @"Delete",
            @"캐시 용량 한도": @"Cache size limit",
            @"Spotify가 캐시된 콘텐츠에 사용하는 저장 공간을 관리합니다.": @"Manages the storage Spotify uses for cached content.",
            @"더 알아보기": @"Learn more",
            @"Spotify 추천 설정": @"Spotify recommended setting",
            @"캐시 지우기": @"Clear cache",
            @"데이터를 삭제해 일시적으로 저장 공간을 확보하거나 캐시 한도를 설정해 저장 공간을 자동으로 관리해 보세요. 다운로드한 항목은 삭제되지 않습니다.":
                @"Delete data to free up storage for now, or set a cache limit to manage storage automatically. Downloaded items are not deleted.",
            @"지우기": @"Clear",
            // The two sheets the Delete and Clear buttons open.
            @"다운로드 항목을 모두 삭제할까요?": @"Delete all downloads?",
            @"이 기기에 이미 다운로드되어 있는 콘텐츠를 더 이상 오프라인에서 이용할 수 없게 됩니다.":
                @"Content already downloaded to this device will no longer be available offline.",
            @"취소": @"Cancel",
            @"대신 캐시 한도를 설정하시겠어요?": @"Set a cache limit instead?",
            @"캐시를 삭제하면 재생 환경에 일시적으로 영향을 줄 수 있으며 데이터 사용량이 증가할 수 있습니다. 대신 캐시 한도를 설정하면 저장 공간이 자동으로 관리됩니다.":
                @"Clearing the cache may briefly affect playback and increase data use. Setting a cache limit instead manages storage automatically.",
            @"한도 설정": @"Set limit",
            @"그래도 지우기": @"Clear anyway",
            // The sheet that Learn more opens.
            @"캐시 용량 한도 정보": @"About cache size limit",
            @"다운로드 항목은 안전하게 보관됩니다. 이 설정을 변경해도 다운로드한 음악이나 팟캐스트는 절대 삭제되지 않습니다.":
                @"Your downloads are kept safe. Changing this setting never deletes the music or podcasts you downloaded.",
            @"휴대폰은 안전하게 보호됩니다. Spotify는 어느 설정을 선택하든 기기 공간에 항상 여유를 둡니다.":
                @"Your phone stays protected. Whichever setting you choose, Spotify always leaves free space on your device.",
            @"캐시 용량이 클수록 재생이 더 원활해지고 데이터 사용량도 줄어듭니다.":
                @"A larger cache makes playback smoother and uses less data.",
            @"확인": @"OK",
        };
    });
    return table;
}

static BOOL SGStorageWantsEnglish(void) {
    return [SGLanguage() isEqualToString:@"en"];
}

// The English for a Korean text of the page, or nil: the whole text, or the name before a legend's " | size".
static NSString *SGStorageTranslate(NSString *text) {
    if (!text.length || !SGStorageWantsEnglish()) return nil;
    NSCharacterSet *space = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    // Line breaks and runs of spaces read as one space, so a text Spotify wraps by hand is still the same text.
    NSMutableArray<NSString *> *words = [NSMutableArray array];
    for (NSString *word in [text componentsSeparatedByCharactersInSet:space]) if (word.length) [words addObject:word];
    NSString *trimmed = [words componentsJoinedByString:@" "];
    NSString *english = SGStorageEnglish()[trimmed];
    if (english) return english;
    NSRange bar = [trimmed rangeOfString:@" | "];
    if (bar.location == NSNotFound) return nil;
    NSString *name = SGStorageEnglish()[[trimmed substringToIndex:bar.location]];
    return name ? [name stringByAppendingString:[trimmed substringFromIndex:bar.location]] : nil;
}

// The same for an attributed text (the note with its info mark): the texts that carry a Korean line keep their
// attributes, and the mark in front of it stays.
static NSAttributedString *SGStorageTranslateAttributed(NSAttributedString *text) {
    if (!text.length || !SGStorageWantsEnglish()) return text;
    NSString *plain = text.string;
    NSString *whole = SGStorageTranslate(plain);
    NSMutableAttributedString *mutable = [text mutableCopy];
    if (whole) {
        NSRange range = NSMakeRange(0, plain.length);
        NSCharacterSet *space = NSCharacterSet.whitespaceAndNewlineCharacterSet;
        while (range.length && [space characterIsMember:[plain characterAtIndex:range.location]]) { range.location++; range.length--; }
        while (range.length && [space characterIsMember:[plain characterAtIndex:NSMaxRange(range) - 1]]) range.length--;
        [mutable replaceCharactersInRange:range withString:whole];
        return mutable;
    }
    NSArray<NSString *> *keys = [SGStorageEnglish().allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return a.length < b.length ? NSOrderedDescending : a.length > b.length ? NSOrderedAscending : NSOrderedSame;
    }];
    for (NSString *korean in keys) {
        if (korean.length < 8) continue;
        NSRange found = [mutable.string rangeOfString:korean];
        if (found.location != NSNotFound) { [mutable replaceCharactersInRange:found withString:SGStorageEnglish()[korean]]; break; }
    }
    return mutable;
}

// The two sheets (Delete all downloads, Clear cache) are presented from the page, so they are views of their
// own: the one presented while the page is on screen is claimed, weakly, and set in Retrine's type too.
static NSHashTable<UIView *> *sg_sheetViews;
static const void *kStorageSheet = &kStorageSheet;

static BOOL SGOnStorageSheet(UIView *view) {
    if (!sg_sheetViews || sg_storageApplying || !view || ![NSThread isMainThread]) return NO;
    for (UIView *root in sg_sheetViews) {
        if (view == root || [view isDescendantOfView:root]) return YES;
    }
    return NO;
}

// Whether a control or a rounded, outlined or filled view holds the label: a button's text.
static BOOL SGStorageInButton(UIView *label) {
    UIView *view = label.superview;
    for (int level = 0; view && level < 4; level++, view = view.superview) {
        if ([view isKindOfClass:UIControl.class] && ![view isKindOfClass:UISwitch.class] && ![view isKindOfClass:UISlider.class]) return YES;
        if (view.layer.borderWidth > 0 && view.bounds.size.height <= 80) return YES;
        if (view.layer.cornerRadius >= 14 && view.bounds.size.height <= 80 && view.bounds.size.height > 0) return YES;
    }
    return NO;
}

static BOOL SGStorageIsGreen(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a] || a < 0.5) return NO;
    return g > r + 0.2 && g > b + 0.2;
}

// A button's text never cuts to an ellipsis: Spotify sizes the button for the words it had, and the English or
// Retrine's type may need more, until something lays it out again.
// Only a label whose words or type changed asks, and after the current pass: Spotify sets labels while it lays
// out, so a layout asked for inside a layout, by every set, would never end.
static const void *kStorageRelayouts = &kStorageRelayouts;

static void SGStorageRelayout(UILabel *label) {
    // A label Spotify sets back to its own words at every layout is asked for a few times, not for ever.
    NSInteger asked = [objc_getAssociatedObject(label, kStorageRelayouts) integerValue];
    if (asked >= 3) return;
    objc_setAssociatedObject(label, kStorageRelayouts, @(asked + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UILabel *weak = label;
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *strong = weak;
        if (!strong) return;
        [strong invalidateIntrinsicContentSize];
        UIView *view = strong.superview;
        for (int level = 0; view && level < 3; level++, view = view.superview) {
            [view invalidateIntrinsicContentSize];
            [view setNeedsLayout];
        }
    });
}

static BOOL SGStorageLabelChanged(UILabel *label, NSAttributedString *beforeText, UIFont *beforeFont) {
    return ![label.attributedText isEqualToAttributedString:beforeText] || ![label.font isEqual:beforeFont];
}

static void SGStorageFitButtonLabel(UILabel *label) {
    if (label.numberOfLines > 1 || !SGStorageInButton(label)) return;
    if (!label.adjustsFontSizeToFitWidth) label.adjustsFontSizeToFitWidth = YES;
    if (label.minimumScaleFactor < 0.7) label.minimumScaleFactor = 0.7;
    if (label.lineBreakMode != NSLineBreakByClipping) label.lineBreakMode = NSLineBreakByClipping;
}

// A sheet's own roles: the headline, the text under it and the buttons, in Retrine's typeface and grays, at the
// sizes Spotify gave them.
static void SGSheetStyleLabel(UILabel *label) {
    NSString *plain = label.attributedText.length ? label.attributedText.string : label.text;
    if (!plain.length || [plain rangeOfCharacterFromSet:NSCharacterSet.alphanumericCharacterSet].location == NSNotFound) return;
    NSAttributedString *beforeText = [label.attributedText copy];
    UIFont *beforeFont = label.font;
    sg_storageApplying = YES;
    if (label.attributedText.length) {
        NSAttributedString *translated = SGStorageTranslateAttributed(label.attributedText);
        if (![translated isEqualToAttributedString:label.attributedText]) label.attributedText = translated;
    } else {
        NSString *english = SGStorageTranslate(label.text);
        if (english && ![label.text isEqualToString:english]) label.text = english;
    }
    BOOL button = SGStorageInButton(label);
    BOOL bold = label.font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold;
    // Spotify's size stays: the sheet is read at the size it was made for. Retrine's typeface (the app font of
    // Shared/Fonts included) and its white and gray take the place of Spotify's.
    UIFontDescriptor *face = SGTitleFont().fontDescriptor;
    if (bold || button) {
        UIFontDescriptor *heavy = [face fontDescriptorWithSymbolicTraits:face.symbolicTraits | UIFontDescriptorTraitBold];
        if (heavy) face = heavy;
    }
    UIFont *font = [UIFont fontWithDescriptor:face size:label.font.pointSize];
    UIColor *color = label.textColor;
    if (!button) color = bold ? UIColor.whiteColor : SGGrey();
    if (![label.font isEqual:font]) label.font = font;
    if (![label.textColor isEqual:color]) label.textColor = color;
    if (button) {
        SGStorageFitButtonLabel(label);
        UIView *fill = label.superview;
        for (int level = 0; fill && level < 4; level++, fill = fill.superview) {
            if (SGStorageIsGreen(fill.backgroundColor)) {
                if (![label.textColor isEqual:SGOnAccent()]) label.textColor = SGOnAccent();
                break;
            }
        }
    }
    sg_storageApplying = NO;
    if (SGStorageLabelChanged(label, beforeText, beforeFont)) SGStorageRelayout(label);
}

static void SGSheetStyleTree(UIView *view) {
    if ([view isKindOfClass:UILabel.class]) {
        SGSheetStyleLabel((UILabel *)view);
    } else if (SGStorageIsGreen(view.backgroundColor) && view.layer.cornerRadius >= 14) {
        if (![view.backgroundColor isEqual:SGGreen()]) view.backgroundColor = SGGreen();
    }
    for (UIView *child in view.subviews) SGSheetStyleTree(child);
}

static void SGClaimStorageSheet(UIViewController *controller) {
    if (!controller.isViewLoaded) return;
    if (!sg_sheetViews) sg_sheetViews = [NSHashTable weakObjectsHashTable];
    [sg_sheetViews addObject:controller.view];
    SGSheetStyleTree(controller.view);
}

// Whether the Data Saver and Offline page is the one on screen below `controller`: through navigation stacks
// and tabs to what shows.
static BOOL SGShowsDataSaver(UIViewController *controller) {
    if (!controller) return NO;
    if (SGIsDataSaverPage(controller)) return YES;
    if ([controller isKindOfClass:UINavigationController.class]) return SGShowsDataSaver(((UINavigationController *)controller).topViewController);
    if ([controller isKindOfClass:UITabBarController.class]) return SGShowsDataSaver(((UITabBarController *)controller).selectedViewController);
    for (UIViewController *child in controller.childViewControllers) if (SGShowsDataSaver(child)) return YES;
    return NO;
}

static BOOL SGPresentsFromDataSaver(UIViewController *presenter) {
    if (!sg_storageClaimed) return NO;
    for (UIViewController *up = presenter; up; up = up.parentViewController) {
        if (SGIsDataSaverPage(up)) return YES;
    }
    if (presenter.isViewLoaded && SGOnStoragePage(presenter.view)) return YES;
    UIViewController *root = presenter;
    while (root.parentViewController) root = root.parentViewController;
    return SGShowsDataSaver(root) || SGShowsDataSaver(SGTopController());
}

static void SGStorageStyleLabel(UILabel *label) {
    if (SGOnStorageSheet(label)) { SGSheetStyleLabel(label); return; }
    if (!SGOnStoragePage(label)) return;
    NSString *plain = label.attributedText.length ? label.attributedText.string : label.text;
    // A legend's dot or a bullet is a mark, not text, and keeps its color.
    if (!plain.length || [plain rangeOfCharacterFromSet:NSCharacterSet.alphanumericCharacterSet].location == NSNotFound) return;
    NSAttributedString *beforeText = [label.attributedText copy];
    UIFont *beforeFont = label.font;
    sg_storageApplying = YES;
    if (label.attributedText.length) {
        NSAttributedString *translated = SGStorageTranslateAttributed(label.attributedText);
        NSAttributedString *mapped = SGMappedText(translated, label.font);
        if (![mapped isEqualToAttributedString:label.attributedText]) label.attributedText = mapped;
    } else {
        NSString *english = SGStorageTranslate(label.text);
        if (english && ![label.text isEqualToString:english]) label.text = english;
        SGStorageRole role = SGRoleFor(label.font, label.textColor);
        UIFont *font = SGMappedFont(label.font, role);
        if (![label.font isEqual:font]) label.font = font;
        UIColor *color = SGMappedColor(label.textColor, role);
        if (![label.textColor isEqual:color]) label.textColor = color;
        if (role == SGStorageHeader && ![label.text isEqualToString:label.text.uppercaseString]) {
            label.text = label.text.uppercaseString;
        }
        SGStorageFitButtonLabel(label);
    }
    sg_storageApplying = NO;
    if (SGStorageLabelChanged(label, beforeText, beforeFont)) SGStorageRelayout(label);
}

static void SGStorageStyleTree(UIView *view) {
    if ([view isKindOfClass:UILabel.class]) {
        SGStorageStyleLabel((UILabel *)view);
    } else if ([view isKindOfClass:UISwitch.class]) {
        ((UISwitch *)view).onTintColor = SGGreen();
    } else if ([view isKindOfClass:UISlider.class]) {
        UISlider *slider = (UISlider *)view;
        slider.minimumTrackTintColor = SGGreen();
        slider.maximumTrackTintColor = SGGrey();
    } else if ([view isKindOfClass:UIScrollView.class]) {
        view.backgroundColor = SGPageBackground();
    }
    for (UIView *child in view.subviews) SGStorageStyleTree(child);
}

static NSString *SGPageTitle(UIViewController *controller);
static void SGStorageTranslateTitle(UIViewController *controller) {
    for (UIViewController *page = controller; page; page = page.parentViewController) {
        NSString *english = SGStorageTranslate(SGPageTitle(page));
        if (!english) continue;
        sg_storageApplying = YES;
        page.title = english;
        page.navigationItem.title = english;
        sg_storageApplying = NO;
    }
}

// Spotify's settings list paints nothing of its own and shows what is under it: the wrapper every pushed page
// gets, and under that the stack's own gray. The page comes in over the screen before it, so all of them go
// black together with the list, from the first frame; otherwise the page is seen light and then goes dark.
static void SGStorageBlacken(UIViewController *controller) {
    for (UIViewController *up = controller; up && ![up isKindOfClass:UINavigationController.class]; up = up.parentViewController) {
        if (up.isViewLoaded && ![up.view.backgroundColor isEqual:SGPageBackground()]) up.view.backgroundColor = SGPageBackground();
    }
}

static void SGStyleDataSaverPage(UIViewController *controller) {
    if (!controller.isViewLoaded) return;
    SGStorageBlacken(controller);
    SGStorageTranslateTitle(controller);
    SGClaimStorageController(controller);
    controller.view.backgroundColor = SGPageBackground();
    SGStorageStyleTree(controller.view);
}

// The page's controller, or the one among its children that carries the title: what is pushed is the wrapper
// every page gets (see App/ModSettings.x), and the title is on the list inside it, if it is set yet.
static UIViewController *SGDataSaverIn(UIViewController *controller) {
    if (SGIsDataSaverPage(controller)) return controller;
    for (UIViewController *child in controller.childViewControllers) {
        UIViewController *found = SGDataSaverIn(child);
        if (found) return found;
    }
    return nil;
}

static NSString *SGPageTitle(UIViewController *controller) {
    return controller.navigationItem.title ?: controller.title;
}

static const void *kStorageListClaimed = &kStorageListClaimed;

// A settings list, before its first frame: its own title or the wrapper's says whether it is the Data Saver
// and Offline page, and a list that has no title at all while Mod › Storage's request is fresh is that page.
// It is claimed once, and its labels are then set in Retrine's type as Spotify fills the list in.
static void SGClaimDataSaverList(UIViewController *list) {
    if (!list.isViewLoaded || objc_getAssociatedObject(list, kStorageListClaimed)) return;
    UIViewController *page = nil;
    BOOL titled = NO;
    for (UIViewController *up = list; up; up = up.parentViewController) {
        if (SGPageTitle(up).length) titled = YES;
        if (!page && SGIsDataSaverPage(up)) page = up;
    }
    if (!page && !titled && SGStorageRequested()) {
        page = list;
        sg_storageRequestedAt = 0;
    }
    if (!page) return;
    objc_setAssociatedObject(list, kStorageListClaimed, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SGStorageBlacken(list);
    SGStyleDataSaverPage(page);
}

%hook UIViewController
- (void)presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion {
    BOOL fromPage = controller && SGPresentsFromDataSaver((UIViewController *)self);
    if (fromPage) objc_setAssociatedObject(controller, kStorageSheet, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig;
    if (!fromPage) return;
    // Its labels may be set as it loads, so they are taken now and again as it lays out and appears.
    SGClaimStorageSheet(controller);
    dispatch_async(dispatch_get_main_queue(), ^{ SGClaimStorageSheet(controller); });
}
- (void)viewDidLayoutSubviews {
    %orig;
    if (objc_getAssociatedObject(self, kStorageSheet)) SGClaimStorageSheet((UIViewController *)self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (objc_getAssociatedObject(self, kStorageSheet)) SGClaimStorageSheet((UIViewController *)self);
}
%end

%hook UINavigationController
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // The page that Mod › Storage asked for is black before it slides in, not after: an untitled page pushed
    // while the request is fresh, or one that is the Data Saver page already.
    if (viewController && (SGIsDataSaverPage(viewController) || (SGStorageRequested() && !SGPageTitle(viewController).length))) {
        [viewController loadViewIfNeeded];
        SGStorageBlacken(viewController);
        for (UIViewController *child in viewController.childViewControllers) {
            if (child.isViewLoaded && ![child.view.backgroundColor isEqual:SGPageBackground()]) child.view.backgroundColor = SGPageBackground();
        }
    }
    %orig;
    // After the push, with the page on the stack: Mod Settings' row goes onto any settings list that has no
    // stack yet (App/ModSettings.x), so a page loaded and laid out before this would get it.
    if (SGDataSaverIn(viewController)) SGStyleDataSaverPage(viewController);
}
%end

// The list itself, as it loads, appears and lays out: the first of these that can tell the page by its title
// styles it, so the page is not seen in Spotify's type first. viewDidAppear is the last of them, for a page
// that came up another way.
%hook _TtC21Settings_PlatformImpl26SettingsListViewController
- (void)viewDidLoad {
    %orig;
    SGClaimDataSaverList((UIViewController *)self);
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    SGClaimDataSaverList((UIViewController *)self);
}
- (void)viewDidLayoutSubviews {
    %orig;
    SGClaimDataSaverList((UIViewController *)self);
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    for (UIViewController *page = (UIViewController *)self; page; page = page.parentViewController) {
        if (!SGIsDataSaverPage(page)) continue;
        SGStyleDataSaverPage(page);
        break;
    }
}
%end

%hook UILabel
- (void)didMoveToWindow {
    %orig;
    SGStorageStyleLabel(self);
}
- (void)setFont:(UIFont *)font {
    %orig;
    SGStorageStyleLabel(self);
}
- (void)setTextColor:(UIColor *)color {
    %orig;
    SGStorageStyleLabel(self);
}
- (void)setText:(NSString *)text {
    %orig;
    SGStorageStyleLabel(self);
}
- (void)setAttributedText:(NSAttributedString *)text {
    %orig;
    SGStorageStyleLabel(self);
}
%end

%hook UISwitch
- (void)didMoveToWindow {
    %orig;
    if (SGOnStoragePage(self)) self.onTintColor = SGGreen();
}
%end

%hook UISlider
- (void)didMoveToWindow {
    %orig;
    if (!SGOnStoragePage(self)) return;
    self.minimumTrackTintColor = SGGreen();
    self.maximumTrackTintColor = SGGrey();
}
%end

%ctor {
    %init;
    [NSNotificationCenter.defaultCenter addObserverForName:kStoragePageRequested object:nil queue:nil
                                                usingBlock:^(NSNotification *note) {
        sg_storageRequestedAt = [NSDate timeIntervalSinceReferenceDate];
    }];
}
