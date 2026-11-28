#pragma once
#import <UIKit/UIKit.h>

UIImage *SAPArtistArtworkPlaceholder(void);
NSString *SAPArtistReleaseCategoryTitle(NSDictionary *release);
NSString *SAPArtistTrackCounter(NSUInteger downloaded,NSUInteger total);
UIImageView *SAPArtistStateIcon(NSString *symbol,UIColor *color,NSString *label);
// Retrine's accent, or the system green while Retrine's style is not loaded.
UIColor *SAPArtistAccent(void);
// Retrine's 13pt white title over an 11pt gray subtitle for a list row; a no-op while its style is not loaded.
void SAPApplyRetrineRowText(UIListContentConfiguration *content);

@interface SAPArtistProgressAccessory : UIView
- (instancetype)initWithDownloaded:(NSUInteger)downloaded total:(NSUInteger)total progress:(double)progress;
- (void)updateDownloaded:(NSUInteger)downloaded total:(NSUInteger)total progress:(double)progress;
@end

@interface SAPArtistReleaseCell : UITableViewCell
@property(nonatomic,strong) UIView *indicatorHost;
@property(nonatomic,copy) NSArray<NSLayoutConstraint *> *indicatorConstraints,*indicatorChildConstraints;
@property(nonatomic,strong) UIView *downloadIndicator;
@property(nonatomic,strong) UIImageView *staticIndicator;
@property(nonatomic,strong) SAPArtistProgressAccessory *progressIndicator;
@property(nonatomic,copy) NSString *indicatorKind;
@property(nonatomic,copy) NSDictionary *renderedRelease,*renderedState;
@property(nonatomic) BOOL renderedSelecting,renderedSelected;
@property(nonatomic,copy) dispatch_block_t cancelArtwork;
- (void)cancelArtworkLoad;
- (UIView *)indicatorForState:(NSDictionary *)state;
- (void)installIndicatorLayout;
- (void)setDownloadIndicator:(UIView *)indicator;
@end

@interface SAPArtistCategoryHeader : UITableViewHeaderFooterView
@property(nonatomic,strong) UILabel *categoryTitle,*catalogProgressLabel;
@property(nonatomic,strong) UIButton *selectionButton;
@end
