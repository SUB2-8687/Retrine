#import "RetrineStyle.h"
#include <dlfcn.h>

static void *SAPStyleSymbol(const char *name) {return dlsym(RTLD_DEFAULT,name);}

BOOL SAPRetrineStyleLoaded(void) {
    static BOOL loaded;
    if(loaded)return YES;
    static const char *const names[]={
        "SGFillCell","SGTileImage","SGTileImageTinted","SGChevronView","SGSectionHeader","SGSectionHeaderHeight",
        "SGSectionFooter","SGSectionFooterHeight","SGCardBackground","SGPageBackground","SGGreen","SGGrey",
        "SGTitleFont","SGSubtitleFont","SGTileRowInset","SGSectionGap"};
    for(unsigned i=0;i<sizeof(names)/sizeof(*names);i++)if(!SAPStyleSymbol(names[i]))return NO;
    loaded=YES;return YES;
}

static UIColor *SAPStyleColor(const char *name) {
    UIColor *(*color)(void)=SAPStyleSymbol(name);
    return color?color():nil;
}
UIColor *SAPStyleCard(void) {return SAPStyleColor("SGCardBackground");}
UIColor *SAPStylePage(void) {return SAPStyleColor("SGPageBackground");}
UIColor *SAPStyleGreen(void) {return SAPStyleColor("SGGreen");}
UIColor *SAPStyleGrey(void) {return SAPStyleColor("SGGrey");}

static UIFont *SAPStyleFont(const char *name) {
    UIFont *(*font)(void)=SAPStyleSymbol(name);
    return font?font():nil;
}
UIFont *SAPStyleTitleFont(void) {return SAPStyleFont("SGTitleFont");}
UIFont *SAPStyleSubtitleFont(void) {return SAPStyleFont("SGSubtitleFont");}

BOOL SAPStyleFillCell(UITableViewCell *cell, NSString *title, NSString *subtitle) {
    if(!SAPRetrineStyleLoaded())return NO;
    void (*fill)(UITableViewCell *,NSString *,NSString *,UIColor *,NSString *)=SAPStyleSymbol("SGFillCell");
    fill(cell,title,subtitle,nil,nil);return YES;
}

UIImage *SAPStyleTile(NSString *symbol, UIColor *color) {
    if(!symbol.length)return nil;
    UIImage *(*gray)(NSString *)=SAPStyleSymbol("SGTileImage");
    UIImage *(*tinted)(NSString *,UIColor *)=SAPStyleSymbol("SGTileImageTinted");
    // A white square would hide the white symbol on it, so it stands for Retrine's own gray one.
    if(!color||[color isEqual:UIColor.whiteColor])return gray?gray(symbol):nil;
    return tinted?tinted(symbol,color):nil;
}

UIView *SAPStyleChevron(void) {
    UIView *(*chevron)(void)=SAPStyleSymbol("SGChevronView");
    return chevron?chevron():nil;
}

static CGFloat SAPStyleConstant(const char *name, CGFloat fallback) {
    const CGFloat *value=SAPStyleSymbol(name);
    return value?*value:fallback;
}
CGFloat SAPStyleTileInset(void) {return SAPStyleConstant("SGTileRowInset",58);}
CGFloat SAPStyleSectionGap(void) {return SAPStyleConstant("SGSectionGap",20);}

UIView *SAPStyleHeader(UITableView *table, NSString *title) {
    UIView *(*header)(UITableView *,NSString *)=SAPStyleSymbol("SGSectionHeader");
    return header?header(table,title):nil;
}
CGFloat SAPStyleHeaderHeight(void) {
    CGFloat (*height)(void)=SAPStyleSymbol("SGSectionHeaderHeight");
    return height?height():UITableViewAutomaticDimension;
}
UIView *SAPStyleFooter(UITableView *table, NSString *text) {
    UIView *(*footer)(UITableView *,NSString *)=SAPStyleSymbol("SGSectionFooter");
    return footer?footer(table,text):nil;
}
CGFloat SAPStyleFooterHeight(UITableView *table, NSString *text) {
    CGFloat (*height)(UITableView *,NSString *)=SAPStyleSymbol("SGSectionFooterHeight");
    return height?height(table,text):UITableViewAutomaticDimension;
}
