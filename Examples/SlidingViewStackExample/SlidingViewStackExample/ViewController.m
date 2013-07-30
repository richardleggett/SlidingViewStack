//
//  ViewController.m
//  SlidingViewStackExample
//
//  Created by Richard Leggett on 23/07/2013.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (strong, nonatomic) SlidingViewStack *viewStack;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated
{
    self.viewStack = [[SlidingViewStack alloc] initWithFrame:self.view.bounds];
    self.viewStack.delegate = self;
    self.viewStack.dataSource = self;
    self.viewStack.wrapEnabled = YES;
    [self.view addSubview:_viewStack];
    
    // try out some auto-scroll
//    [self.viewStack scrollByNumberOfItems:5 duration:5.0];
//    [self.viewStack scrollToItemAtIndex:4 duration:2.0];
}

#pragma mark SlidingViewStackDataSource methods

- (NSInteger)numberOfItemsInViewStack:(SlidingViewStack *)viewStack
{
    return 10;
}

- (UIView *)slidingViewStack:(SlidingViewStack *)viewStack viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    UILabel* label;
    
    if(!view) {
        label = [[UILabel alloc] initWithFrame:self.view.bounds];
        view = label;
    } else {
        label = (UILabel*)view;
    }
    label.backgroundColor = (index%2==0) ? [UIColor redColor] : [UIColor blueColor];
    label.text = [NSString stringWithFormat:@"%d", index];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [label.font fontWithSize:50];
    
    UIButton *button =  [UIButton buttonWithType:UIButtonTypeRoundedRect];;
    button.frame = CGRectMake(self.view.bounds.size.width/2-50, self.view.bounds.size.height-100, 100, 50);
    [button setTitle:@"Back to 0" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(handleButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:button];
    
    view.userInteractionEnabled = YES;
    
    return view;
}

#pragma mark SlidingViewStackDelegate methods

// return a CGSize for each item View or leave unimplemented to use the view size from a view returned by
// [viewStack slidingViewStack:viewStack viewForItemAtIndex:0 reusingView:nil]
//- (CGSize)slidingViewStackItemSize:(SlidingViewStack *)viewStack
//{
//}

- (void)slidingViewStackDidScroll:(SlidingViewStack *)viewStack
{
}

- (void)slidingViewStackCurrentItemIndexDidChange:(SlidingViewStack *)viewStack
{
    NSLog(@"slidingViewStackCurrentItemIndexDidChange to %d", [viewStack currentItemIndex]);
}

- (void)slidingViewStackWillBeginDragging:(SlidingViewStack *)viewStack
{
    NSLog(@"slidingViewStackWillBeginDragging");
}

- (void)slidingViewStackDidEndDragging:(SlidingViewStack *)viewStack
{
    NSLog(@"slidingViewStackDidEndDragging");
}

- (void)slidingViewStackDidEndScrollingAnimation:(SlidingViewStack *)viewStack
{
    NSLog(@"slidingViewStackDidEndScrollingAnimation");
}


#pragma mark Button handler

- (void)handleButtonPressed:(UIButton*)button
{
    [self.viewStack scrollToItemAtIndex:0 duration:1.0];
}

#pragma mark -

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    self.viewStack.delegate = nil;
    self.viewStack.dataSource = nil;
}

@end
