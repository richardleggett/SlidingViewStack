SlidingViewStack
================

Overview
--------------

SlidingViewStack creates a z-ordered stack of views that users can scroll through either by flinging or swiping horizontally or vertically depending on the .vertical property. 

Wrapping is also supported to allow the stack to loop when the last item is reached, or when going backwards from the first item to the last.

SlidingViewStack uses UITableView-style dataSource/delegate protocols for view loading and events and recycles views internally for efficient memory use.

Sample Output
------------------

![Output sample](https://github.com/richardleggett/SlidingViewStack/raw/master/SlidingViewStack.gif)

ARC Compatibility
------------------

SlidingViewStack was designed to be used with ARC enabled.

Sample Usage
--------------

An example project has been included, but usage is similar to UITableView.
    
    - (void)viewDidAppear:(BOOL)animated
	{
	    self.viewStack = [[SlidingViewStack alloc] initWithFrame:self.view.bounds];
	    self.viewStack.delegate = self;
	    self.viewStack.dataSource = self;
	    self.viewStack.wrapEnabled = YES;
	    [self.view addSubview:self.viewStack];
	}
	
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
	    	    
	    return view;
	}
	
License 
--------------
zlib (please see [LICENSE.md](https://github.com/richardleggett/SlidingViewStack/raw/master/LICENSE.md))