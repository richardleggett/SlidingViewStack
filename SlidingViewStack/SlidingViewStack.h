//
//  SlidingViewStack.h
//
//  A swipeable stack of views.
//  Swiping the top view off to the right or bottom (depending on isVertical)
//  reveals the view beneath, swiping in the reverse direction brings back the
//  preview view in the stack.
//
//  Created by Richard Leggett on 23/07/2013.
//  Copyright (c) 2013 Richard Leggett. 
//
//  Inspired by Nick Lockwood's SwipeView architecture:
//  https://github.com/nicklockwood/SwipeView/
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//  http://zlib.net/zlib_license.html
//

#import <UIKit/UIKit.h>

@protocol SlidingViewStackDataSource, SlidingViewStackDelegate;

@interface SlidingViewStack : UIView

@property (nonatomic, weak) IBOutlet id<SlidingViewStackDataSource> dataSource;
@property (nonatomic, weak) IBOutlet id<SlidingViewStackDelegate> delegate;

@property (nonatomic, readonly) NSInteger numberOfItems;
@property (nonatomic, readonly) CGSize itemSize;
@property (nonatomic, weak, readonly) UIView *currentItemView;
@property (nonatomic, assign) NSInteger currentItemIndex;
@property (nonatomic, assign, getter = isWrapEnabled) BOOL wrapEnabled;
@property (nonatomic, readonly, getter = isDragging) BOOL dragging;
@property (nonatomic, readonly, getter = isScrolling) BOOL scrolling;
@property (nonatomic, readonly, getter = isFlinging) BOOL flinging;

/**
 * (default YES), when in wrapEnabled mode scrolling will occur via the shortest path, 
 * so from 6 to 0 goes via 7>8>9>0 with a total of 10 items, instead of 6>5>4>3>2>1>0
 */
@property (nonatomic, assign) BOOL allowScrollViaShortestRoute;
/**
 * (default YES) whether we are operating in vertical mode, otherwise horizontal is assumed
 */
@property (nonatomic, assign, getter = isVertical) BOOL vertical;
/**
 * The distance from the edge (in points) which dictates whether we snap to the next item view, 
 * or snap back to the current one when dragging
 */
@property (nonatomic, assign) float snapDistance;
/**
 * The acceleration in points-per-second after which we 
 * treat a drag-and-release as a fling (default is 1.0)
 */
@property (nonatomic, assign) float flingThreshhold;
/**
 * (default YES) adjusts the darkness of the view visually behind view
 * currently being scrolled into/out of view
 */
@property (nonatomic, assign) BOOL darkenViewBehind;


- (void)reloadData;
- (void)reloadItemAtIndex:(NSInteger)index;
- (void)scrollByNumberOfItems:(NSInteger)itemCount duration:(NSTimeInterval)duration;
- (void)scrollToItemAtIndex:(NSInteger)index duration:(NSTimeInterval)duration;
- (UIView *)itemViewAtIndex:(NSInteger)index;
- (NSInteger)indexOfItemView:(UIView *)view;

@end

@protocol SlidingViewStackDataSource <NSObject>
- (NSInteger)numberOfItemsInViewStack:(SlidingViewStack *)viewStack;
- (UIView *)slidingViewStack:(SlidingViewStack *)viewStack viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view;
@end

@protocol SlidingViewStackDelegate <NSObject>
@optional

- (CGSize)slidingViewStackItemSize:(SlidingViewStack *)viewStack;
- (void)slidingViewStackDidScroll:(SlidingViewStack *)viewStack;
- (void)slidingViewStackCurrentItemIndexDidChange:(SlidingViewStack *)viewStack;
- (void)slidingViewStackWillBeginDragging:(SlidingViewStack *)viewStack;
- (void)slidingViewStackDidEndDragging:(SlidingViewStack *)viewStack;
- (void)slidingViewStackDidEndScrollingAnimation:(SlidingViewStack *)viewStack;

@end

