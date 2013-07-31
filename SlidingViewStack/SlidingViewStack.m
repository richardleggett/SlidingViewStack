//
//  slidingViewStack.m
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
//
//  TODO: Allow swiping in both directions for horizontal and vertical
//

#import "SlidingViewStack.h"

// default value for snapDistance. If the current view is dragged further than snapDistance
// it will automatically snap and animate to the next/previous view in the stack when finger is released
static const float kDefaultSnapDistance = 100.0f;

// default value for scrollDuration
static const float kDefaultScrollDuration = 0.5f;

// default value for scrollDecelleration
static const float kDefaultScrollDecceleration = 5.0f;

// default value for flingThreshold, the threshhold
// at which we determine a drag to be a fling/flick when finger is released
static const float kDefaultFlingThreshhold = 75.0f;

// minimum distance user must drag before we send slidingViewStackWillBeginStartDragging message
static const float kDragMinimum = 4.0f;

// the index of the sub layer in the wrapper view
static NSInteger const kSubViewMainIndex = 0;
static NSInteger const kSubViewOverlayIndex = 1;


@interface SlidingViewStack()

@property (nonatomic, assign) NSInteger numberOfItems;
@property (nonatomic, weak) UIView *currentItemView;
@property (nonatomic, strong) NSMutableDictionary *itemViews;
@property (nonatomic, strong) NSMutableSet *itemViewPool;
@property (nonatomic, assign) NSInteger previousItemIndex;
@property (nonatomic, assign) CGSize itemSize;
@property (nonatomic, assign, getter = isScrolling) BOOL scrolling;
@property (nonatomic, assign) CGFloat scrollOffset;
@property (nonatomic, assign) CGFloat scrollSpeed;
@property (nonatomic, assign) NSTimeInterval scrollDuration;
@property (nonatomic, assign) CGFloat scrollDecceleration;
@property (nonatomic, assign) NSTimeInterval scrollStartTime;
@property (nonatomic, assign) CGFloat startOffset;
@property (nonatomic, assign) CGFloat endOffset;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign, getter = isFlinging) BOOL flinging;
@property (nonatomic, assign, getter = isDragging) BOOL dragging;
@property (nonatomic, assign) CGPoint startTouchPoint;
@property (nonatomic, assign) CGPoint lastTouchPoint;
@property (nonatomic, assign) NSTimeInterval lastTouchTime;

@end

@implementation SlidingViewStack
{
    
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self setUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUp];
    }
    return self;
}

- (void)setUp
{
    self.clipsToBounds = YES;
    self.userInteractionEnabled = YES;
    
    self.snapDistance = kDefaultSnapDistance;
    self.scrollDecceleration = kDefaultScrollDecceleration;
    self.flingThreshhold = kDefaultFlingThreshhold;
    self.wrapEnabled = NO;
    self.vertical = YES;
    self.darkenViewBehind = YES;
    self.allowScrollViaShortestRoute = YES;
    self.itemViews = [NSMutableDictionary dictionary];
    self.lastTouchPoint = CGPointZero;
    self.previousItemIndex = 0;
    self.currentItemIndex = 0;
    self.scrollOffset = 0.0f;
}

- (void)dealloc
{
    [self.timer invalidate];
}

- (void)setDataSource:(id<SlidingViewStackDataSource>)dataSource
{
    if (_dataSource != dataSource)
    {
        _dataSource = dataSource;
        if (_dataSource)
        {
            [self reloadData];
        }
    }
}

- (void)setDelegate:(id<SlidingViewStackDelegate>)delegate
{
    if (_delegate != delegate)
    {
        _delegate = delegate;
		[self setNeedsLayout];
    }
}

- (void)setWrapEnabled:(BOOL)wrapEnabled
{
    if (_wrapEnabled != wrapEnabled)
    {
        _wrapEnabled = wrapEnabled;
        [self setNeedsLayout];
    }
}

- (void)setVertical:(BOOL)vertical
{
    if (_vertical != vertical)
    {
        _vertical = vertical;
        [self setNeedsLayout];
    }
}

#pragma mark View layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateLayout];
}

- (void)updateLayout
{
    [self updateItemSizeAndCount];
    [self updateScrollOffset];
    [self loadUnloadViews];
}

- (void)setFrameForView:(UIView *)view atIndex:(NSInteger)index
{
    // make sure the view is not being animated on
    [UIView setAnimationsEnabled:NO];

    BOOL isBeforeCurrentView = [self isIndexBeforeCurrentItemIndex:index];
    
    CGFloat x = 0, y = 0;
    if(self.vertical)
    {
        y = isBeforeCurrentView ? -self.itemSize.height : 0;
    }
    else
    {
        x = isBeforeCurrentView ? -self.itemSize.width : 0;
    }
    view.frame = CGRectMake(x, y, self.itemSize.width, self.itemSize.height);
    
    // update child view/overlay view width/height
    CGRect subviewFrame = CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
    for (UIView * subview in view.subviews) {
        subview.frame = subviewFrame;
    }
    
    // allow for animations
    [UIView setAnimationsEnabled:YES];
}

#pragma mark Item View management

- (UIView *)itemViewAtIndex:(NSInteger)index
{
    if(index<0 || index>self.numberOfItems)
    {
        NSLog(@"itemViewAtIndex: index is out of bounds");
        return nil;
    }
    return self.itemViews[@(index)];
}

- (BOOL)isIndexBeforeCurrentItemIndex:(NSInteger)index
{
    NSInteger currentNearestIndex = [self clampedOffset:roundf(self.scrollOffset)];
    
    return (index<currentNearestIndex && (index != 0 || currentNearestIndex != self.numberOfItems-1))
    ||
    (index>currentNearestIndex && currentNearestIndex == 0 && index == self.numberOfItems-1);
}

- (UIView *)currentItemView
{
    return [self itemViewAtIndex:self.currentItemIndex];
}

- (NSInteger)indexOfItemView:(UIView *)view
{
    NSInteger index = [[self.itemViews allValues] indexOfObject:view];
    if (index != NSNotFound)
    {
        return [[self.itemViews allKeys][index] integerValue];
    }
    return NSNotFound;
}

- (void)setItemView:(UIView *)view forIndex:(NSInteger)index
{
    self.itemViews[@(index)] = view;
}

#pragma mark View queing

- (void)queueItemView:(UIView *)view
{
    if (view)
    {
        [self.itemViewPool addObject:view];
    }
}

- (UIView *)dequeueItemView
{
    UIView *view = [self.itemViewPool anyObject];
    if (view)
    {
        [self.itemViewPool removeObject:view];
    }
    return view;
}

#pragma mark View loading

- (UIView *)loadViewAtIndex:(NSInteger)index
{
    UIView *viewWrapper;
    UIView *reuseView = [self dequeueItemView];
    UIView *itemView = [self.dataSource slidingViewStack:self
                                         viewForItemAtIndex:index
                                             reusingView:reuseView.subviews[kSubViewMainIndex]];
    
    if(reuseView == nil)
    {
        viewWrapper = [UIView new];
    }
    else
    {
        viewWrapper = reuseView;
    }
    
    if (itemView == nil)
    {
        itemView = [UIView new];
    }
    
    UIView *oldView = [self itemViewAtIndex:index];
    if (oldView)
    {
        [self queueItemView:oldView];
        [oldView removeFromSuperview];
    }
    
    [self setItemView:viewWrapper forIndex:index];
    [self setFrameForView:viewWrapper atIndex:index];
    
    // add original view and "darken overlay" view as subview of viewWrapper
    if(reuseView == nil)
    {
        [viewWrapper addSubview:itemView];
        
        UIView *overlay = [[UIView alloc] initWithFrame:itemView.bounds];
        overlay.backgroundColor = [UIColor blackColor];
        overlay.alpha = 0.0f;
        [viewWrapper addSubview:overlay];
    }
    UIView *overlay = viewWrapper.subviews[kSubViewOverlayIndex];
    overlay.alpha = 0.0f;
    
    BOOL isBeforeCurrentView = [self isIndexBeforeCurrentItemIndex:index];
    if(isBeforeCurrentView)
    {
        [self addSubview:viewWrapper];
    }
    else
    {
        [self insertSubview:viewWrapper atIndex:0];
    }
    
    return viewWrapper;
}

- (void)updateItemSizeAndCount
{
    //get number of items
    self.numberOfItems = [self.dataSource numberOfItemsInViewStack:self];
    
    //get item size
    if ([self.delegate respondsToSelector:@selector(slidingViewStackItemSize:)])
    {
        self.itemSize = [self.delegate slidingViewStackItemSize:self];
    }
    else if (self.numberOfItems > 0)
    {
        UIView *view = self.itemViews[@(0)] ?:
        [self.dataSource slidingViewStack:self viewForItemAtIndex:0 reusingView:[self dequeueItemView]];
        self.itemSize = view.frame.size;
    }
}

/**
 *	Called on initialization and on scroll to determine if new views need to be loaded,
 *  or any off-screen views unloaded (unloaded views are added to the re-use pool)
 */
- (void)loadUnloadViews
{
    // check that item size is known
    CGFloat itemSize = self.vertical ? self.itemSize.height : self.itemSize.width;
    if (itemSize)
    {
        //calculate the index of views showing on screen
        CGFloat clampedOffset = [self clampedOffset:self.scrollOffset];
        
        //we assume there are always 3 "visible" items at any time, previous, current view and next
        NSInteger startIndex = roundf(clampedOffset);
        NSArray *visibleIndices = @[
                                    @([self clampedIndex:startIndex-1]),
                                    @([self clampedIndex:startIndex]),
                                    @([self clampedIndex:startIndex+1])
                                ];
        
        //remove offscreen views
        for (NSNumber *number in [self.itemViews allKeys])
        {
            if (![visibleIndices containsObject:number])
            {
                UIView *view = self.itemViews[number];
                [self queueItemView:view];
                [view removeFromSuperview];
                [self.itemViews removeObjectForKey:number];
            }
        }
        
        //add onscreen views
        for (NSNumber *number in visibleIndices)
        {
            UIView *view = self.itemViews[number];
            if (view == nil)
            {
                [self loadViewAtIndex:[number integerValue]];
            }
        }
    }
}

- (void)reloadItemAtIndex:(NSInteger)index
{
    //if view is visible
    if ([self itemViewAtIndex:index])
    {
        //reload view
        [self loadViewAtIndex:index];
    }
}

- (void)reloadData
{
    //reset properties
    self.scrollOffset = 0.0f;
    self.currentItemIndex = 0;
    self.itemSize = CGSizeZero;
    self.scrolling = NO;
    self.flinging = NO;
    
    //remove old views
    for (UIView *view in self.itemViews) {
        [view removeFromSuperview];
    }
    
    //reset view pools
    self.itemViews = [NSMutableDictionary dictionary];
    self.itemViewPool = [NSMutableSet set];
    
    //layout views
    [self setNeedsLayout];
}

- (void)didMoveToSuperview
{
    if (self.superview)
	{
		[self setNeedsLayout];
        if (self.scrolling)
        {
            [self startAnimation];
        }
	}
    else
    {
        [self stopAnimation];
    }
}

#pragma mark View layout

- (void)updateScrollOffset
{
    // check that item size is known
    CGFloat itemViewSize = self.vertical ? self.itemSize.height : self.itemSize.width;
    if (itemViewSize)
    {
        //calculate indexes of the views showing on screen
        CGFloat scrollOffset = self.scrollOffset;
        
        NSInteger unclampedCurrentScrollIndex = floorf(scrollOffset);
        
        //we assume there are up to 3 "visible" items at any time, previous, current view and next
        NSArray *visibleIndices = @[
                                    @(unclampedCurrentScrollIndex-1),
                                    @(unclampedCurrentScrollIndex),
                                    @(unclampedCurrentScrollIndex+1)
                                    ];
        
        for (NSNumber *number in visibleIndices)
        {
            NSInteger unclampedIndex = [number integerValue];
            NSInteger clampedIndex = [self clampedIndex:unclampedIndex];
            
            // ignore if we are at the first or last and wrap is not enabled
            if(!self.wrapEnabled && clampedIndex != unclampedIndex)
            {
                continue;
            }
            
            // get view for current scrollOffset
            UIView *view = [self itemViewAtIndex:clampedIndex];
            
            // "normalize" scrollOffset to get offset between -1 and 1 from overall scrollOffset
            CGFloat normalizedOffset = unclampedIndex - self.scrollOffset;
            
            // position view based on it's relative scroll offset
            // TODO: MIN(0) must change when we allow reversed scroll directions (right to left and bottom to top)
            CGRect frame = view.frame;
            if(self.vertical)
            {
                // the MIN(0, ...) docks the view to the top/start of the screen as no view scrolls "down"
                // (assuming vertical mode), instead the previous view scrolls in over the top
                frame.origin.y = MIN(0, normalizedOffset * itemViewSize);
            }
            else
            {
                frame.origin.x = MIN(0, normalizedOffset * itemViewSize);
            }
            view.frame = frame;
            
            // adjust darken view overlays based on amount showing
            if(self.darkenViewBehind)
            {
                UIView *overlay = [view.subviews objectAtIndex:kSubViewOverlayIndex];
                if(unclampedIndex>unclampedCurrentScrollIndex)
                {
                    overlay.alpha = powf(normalizedOffset, 2);
                }
                else
                {
                    overlay.alpha = 0.0f;
                }
            }
        }
    }
}

#pragma mark Scrolling

- (void)didScroll
{
    //scroll views
    [self updateScrollOffset];
    
    if ([self.delegate respondsToSelector:@selector(slidingViewStackDidScroll:)])
    {
        [self.delegate slidingViewStackDidScroll:self];
    }
    
    //load views
    [self loadUnloadViews];
}

- (CGFloat)easeInOut:(CGFloat)time
{
    return (time < 0.5f)? 0.5f * powf(time * 2.0f, 3.0f): 0.5f * powf(time * 2.0f - 2.0f, 3.0f) + 1.0f;
}

- (CGFloat)easeOut:(CGFloat)time
{
    return 1.0f - powf(1.0f - time, 2.0f);
}

- (void)step
{
    if (self.scrolling)
    {
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSinceReferenceDate];
        NSTimeInterval time = fminf(1.0f, (currentTime - self.scrollStartTime) / self.scrollDuration);
        CGFloat delta = (self.isFlinging) ? [self easeOut:time] : [self easeInOut:time];
        self.scrollOffset = [self clampedOffset:self.startOffset + (self.endOffset - self.startOffset) * delta];
        
        [self didScroll];
        
        if (time == 1.0f)
        {
            self.scrolling = NO;
            self.flinging = NO;
            [self didScroll];
            if ([self.delegate respondsToSelector:@selector(slidingViewStackDidEndScrollingAnimation:)])
            {
                [self.delegate slidingViewStackDidEndScrollingAnimation:self];
            }
        }
    }
    else
    {
        [self stopAnimation];
        [self updateCurrentItemIndex];
    }
}

- (void)startAnimation
{
    if (!self.timer)
    {
        self.timer = [NSTimer timerWithTimeInterval:1.0/60.0
                                             target:self
                                           selector:@selector(step)
                                           userInfo:nil
                                            repeats:YES];
        
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:UITrackingRunLoopMode];
    }
}

- (void)stopAnimation
{
    [self.timer invalidate];
    self.timer = nil;
}

- (NSInteger)clampedIndex:(NSInteger)index
{
    if (self.wrapEnabled)
    {
        if (self.numberOfItems == 0)
        {
            return 0;
        }
        
        if (index < 0) index += self.numberOfItems;
        return index%self.numberOfItems;
    }
    else
    {
        return MIN(MAX(index, 0), self.numberOfItems - 1);
    }
}

- (CGFloat)clampedOffset:(CGFloat)offset
{
    if (self.wrapEnabled)
    {
        return self.numberOfItems? (offset - floorf(offset / (CGFloat)self.numberOfItems) * self.numberOfItems): 0.0f;
    }
    else
    {
        return fminf(fmaxf(0.0f, offset), (CGFloat)self.numberOfItems - 1.0f);
    }
}

- (NSInteger)numberOfItems
{
    return ((_numberOfItems = [self.dataSource numberOfItemsInViewStack:self]));
}

- (NSInteger)minScrollDistanceFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex
{
    NSInteger directDistance = toIndex - fromIndex;
    if (self.wrapEnabled)
    {
        NSInteger wrappedDistance = MIN(toIndex, fromIndex) + self.numberOfItems - MAX(toIndex, fromIndex);
        if (fromIndex < toIndex)
        {
            wrappedDistance = -wrappedDistance;
        }
        return (ABS(directDistance) <= ABS(wrappedDistance))? directDistance: wrappedDistance;
    }
    return directDistance;
}

- (CGFloat)minScrollDistanceFromOffset:(CGFloat)fromOffset toOffset:(CGFloat)toOffset
{
    CGFloat directDistance = toOffset - fromOffset;
    if (self.wrapEnabled && self.allowScrollViaShortestRoute)
    {
        CGFloat wrappedDistance = fminf(toOffset, fromOffset) + self.numberOfItems - fmaxf(toOffset, fromOffset);
        if (fromOffset < toOffset)
        {
            wrappedDistance = -wrappedDistance;
        }
        return (fabsf(directDistance) <= fabsf(wrappedDistance))? directDistance: wrappedDistance;
    }
    return directDistance;
}

- (void)setCurrentItemIndex:(NSInteger)currentItemIndex
{
    if(_currentItemIndex == currentItemIndex)
    {
        return;
    }
    
    _currentItemIndex = currentItemIndex;
    
    //send index update event on change
    if (self.previousItemIndex != self.currentItemIndex)
    {
        self.previousItemIndex = self.currentItemIndex;
        
        if ([self.delegate respondsToSelector:@selector(slidingViewStackCurrentItemIndexDidChange:)])
        {
            [self.delegate slidingViewStackCurrentItemIndexDidChange:self];
        }
    }
}

- (void)setScrollOffset:(CGFloat)scrollOffset
{
    if (_scrollOffset != scrollOffset)
    {
        _scrollOffset = self.wrapEnabled ? scrollOffset : [self clampedOffset:scrollOffset];
        [self updateLayout];
        [self didScroll];
    }
}

- (void)scrollByOffset:(CGFloat)offset duration:(NSTimeInterval)duration
{
    if (duration > 0.0)
    {
        self.scrolling = YES;
        self.scrollStartTime = [[NSDate date] timeIntervalSinceReferenceDate];
        self.startOffset = self.scrollOffset;
        self.scrollDuration = duration;
        self.endOffset = self.startOffset + offset;
        if (!self.wrapEnabled)
        {
            self.endOffset = [self clampedOffset:self.endOffset];
        }
        [self startAnimation];
    }
    else
    {
        self.scrollOffset += offset;
        [self updateCurrentItemIndex];
    }
}

- (void)scrollToOffset:(CGFloat)offset duration:(NSTimeInterval)duration
{
    [self scrollByOffset:[self minScrollDistanceFromOffset:self.scrollOffset toOffset:offset] duration:duration];
}

- (void)scrollByNumberOfItems:(NSInteger)itemCount duration:(NSTimeInterval)duration
{
    if (duration > 0.0)
    {
        CGFloat offset = 0.0f;
        if (itemCount > 0)
        {
            offset = (floorf(self.scrollOffset) + itemCount) - self.scrollOffset;
        }
        else if (itemCount < 0)
        {
            offset = (ceilf(self.scrollOffset) + itemCount) - self.scrollOffset;
        }
        else
        {
            offset = roundf(self.scrollOffset) - self.scrollOffset;
        }
        [self scrollByOffset:offset duration:duration];
    }
    else
    {
        self.scrollOffset = [self clampedIndex:self.previousItemIndex + itemCount];
    }
}

- (void)scrollToItemAtIndex:(NSInteger)index duration:(NSTimeInterval)duration
{
    [self scrollToOffset:index duration:duration];
}

- (void)updateCurrentItemIndex
{
    //update current item index based on the clamped scrollOffset
    self.currentItemIndex = [self clampedIndex:roundf(self.scrollOffset)];
}

#pragma mark Touch events

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
    CGFloat dx, dy;
    CGPoint pt = [[touches  anyObject] locationInView:self];
    
    if(self.lastTouchPoint.x != 0 && self.lastTouchPoint.y != 0)
    {
        dy = self.lastTouchPoint.y - pt.y;
        dx = self.lastTouchPoint.x - pt.x;
    }
    self.lastTouchPoint = pt;
    
    // see if we've started dragging
    CGFloat totalDragDistance = (self.vertical) ? self.startTouchPoint.y-pt.y : self.startTouchPoint.x-pt.x;
    if(!self.dragging && fabsf(totalDragDistance)>kDragMinimum)
    {
        self.dragging = YES;
        if ([self.delegate respondsToSelector:@selector(slidingViewStackWillBeginDragging:)])
        {
            [self.delegate slidingViewStackWillBeginDragging:self];
        }
    }
    
    //scroll views
    if(self.dragging)
    {
        //stop scrolling animation
        self.scrolling = NO;
        self.flinging = NO;
        
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSinceReferenceDate];
        NSTimeInterval timeDiff = currentTime - self.lastTouchTime;
        self.lastTouchTime = currentTime;
        
        CGFloat delta = self.vertical ? dy : dx;
        
        // update scrollSpeed, points/sec
        self.scrollSpeed = delta/timeDiff;
        self.scrollSpeed /= self.scrollDecceleration;
        self.scrollOffset += delta / (self.vertical ? self.itemSize.height : self.itemSize.width);
        
        //update view and call delegate
        [self didScroll];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.lastTouchTime = [[NSDate date] timeIntervalSinceReferenceDate];
    self.startTouchPoint = [[touches  anyObject] locationInView:self];
    self.scrollSpeed = 0.0f;
    self.scrolling = NO;
    self.flinging = NO;
    
    [self didScroll];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.dragging = NO;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    float itemViewSize = (self.vertical) ? self.bounds.size.height : self.bounds.size.width;
    float scrollDuration = kDefaultScrollDuration * (itemViewSize-fabsf(self.scrollSpeed))/itemViewSize;
    scrollDuration = (scrollDuration<0.1) ? 0.1 : scrollDuration;
    
    // if scroll acceleration is large enough, snap to previous/next
    if(self.scrollSpeed > self.flingThreshhold)
    {
        self.flinging = YES;
        
        // snap to next item view
        int nextIndex = [self clampedIndex:self.currentItemIndex+1];
        [self scrollToItemAtIndex:nextIndex duration:scrollDuration];
    }
    else if(self.scrollSpeed < -self.flingThreshhold)
    {
        self.flinging = YES;
        
        // snap back to previous item view
        int prevIndex = [self clampedIndex:self.currentItemIndex-1];
        [self scrollToItemAtIndex:prevIndex duration:scrollDuration];
    }
    else
    {
        self.flinging = NO;
        
        // snap to current, next or previous item depending on how much we've scrolled by
        float viewScrollOffset = fabs(self.scrollOffset - self.currentItemIndex) * itemViewSize;
        if(viewScrollOffset != 0)
        {
            BOOL isScrollingToNext = self.scrollOffset > self.currentItemIndex;
            if(isScrollingToNext)
            {
                if(viewScrollOffset > self.snapDistance)
                {
                    // snap to next item view
                    int nextIndex = self.currentItemIndex+1;
                    [self scrollToItemAtIndex:nextIndex duration:kDefaultScrollDuration];
                }
                else
                {
                    // snap back to current item view
                    [self scrollToItemAtIndex:self.currentItemIndex duration:kDefaultScrollDuration];
                }
            }
            else
            {
                if(viewScrollOffset > self.snapDistance)
                {
                    // snap back to current item view
                    [self scrollToItemAtIndex:self.currentItemIndex-1 duration:kDefaultScrollDuration];
                }
                else
                {
                    // snap to next item view
                    [self scrollToItemAtIndex:self.currentItemIndex duration:kDefaultScrollDuration];
                }
            }
        }
    }
    
    // setting it back to zero so it doesn't get confused with the last point
    self.lastTouchPoint = CGPointZero;
    
    if(self.dragging)
    {
        self.dragging = NO;
        if ([self.delegate respondsToSelector:@selector(slidingViewStackDidEndDragging:)])
        {
            [self.delegate slidingViewStackDidEndDragging:self];
        }
    }
}
@end
