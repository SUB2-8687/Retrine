#pragma once
#import <UIKit/UIKit.h>

// Retrine's page style, looked up by name from the host process the way SAPL finds SGL: the companion can
// load before or without Retrine, so nothing here links against it. SAPRetrineStyleLoaded() is NO until
// every function below has been found; a caller draws its own look then. Nothing is cached while a
// symbol is missing.
BOOL SAPRetrineStyleLoaded(void);

UIColor *SAPStyleCard(void);       // a card's #1C1C1E
UIColor *SAPStylePage(void);       // the black behind the cards
UIColor *SAPStyleGreen(void);      // the accent, for switches and marks
UIColor *SAPStyleGrey(void);       // secondary text
UIFont *SAPStyleTitleFont(void);   // a row's title and value, 13pt
UIFont *SAPStyleSubtitleFont(void);// subtitles, section headers and notes, 11pt

// A row as Retrine draws it: the white title over the gray subtitle, on a card. Returns NO unstyled.
BOOL SAPStyleFillCell(UITableViewCell *cell, NSString *title, NSString *subtitle);
// The white symbol on a rounded square of `color`; a white or missing color gives Retrine's gray square.
UIImage *SAPStyleTile(NSString *symbol, UIColor *color);
UIView *SAPStyleChevron(void);
CGFloat SAPStyleTileInset(void);   // a tiled row's separator inset

UIView *SAPStyleHeader(UITableView *table, NSString *title);
CGFloat SAPStyleHeaderHeight(void);
CGFloat SAPStyleSectionGap(void);  // above a section with no header
UIView *SAPStyleFooter(UITableView *table, NSString *text);
CGFloat SAPStyleFooterHeight(UITableView *table, NSString *text);
