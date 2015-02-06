//
// UIScrollView+SVInfiniteScrolling.m
//
// Created by Sam Vermette on 23.04.12.
// Copyright (c) 2012 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVPullToRefresh
//

#import <QuartzCore/QuartzCore.h>
#import "UIScrollView+SVInfiniteScrolling.h"

#pragma mark - SVInfiniteScrollingView Interface

static CGFloat const SVInfiniteScrollingViewHeight = 60;

@interface SVInfiniteScrollingView ()

@property (nonatomic, copy) void (^infiniteScrollingHandler)(void);

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, readwrite) SVInfiniteScrollingState state;
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, assign) BOOL isObserving;

- (void)resetScrollViewContentInset;
- (void)setScrollViewContentInsetForInfiniteScrolling;
- (void)setScrollViewContentInset:(UIEdgeInsets)insets;

@end

#pragma mark - UIScrollView (SVInfiniteScrollingView)

#import <objc/runtime.h>

static char UIScrollViewInfiniteScrollingView;

@implementation UIScrollView (SVInfiniteScrolling)

@dynamic infiniteScrollingView;

- (void)addInfiniteScrollingWithActionHandler:(void (^)(void))actionHandler {
    if (!self.infiniteScrollingView) {
        SVInfiniteScrollingView *view = [[SVInfiniteScrollingView alloc] initWithFrame:CGRectMake(0, self.contentSize.height, self.bounds.size.width, SVInfiniteScrollingViewHeight)];
        view.infiniteScrollingHandler = actionHandler;
        view.scrollView = self;
        [self addSubview:view];
        
        self.infiniteScrollingView = view;
        self.showsInfiniteScrolling = (self.frame.size.height > self.contentSize.height);
    }
}

- (void)triggerInfiniteScrolling {
    [self.infiniteScrollingView startAnimating];
}

- (void)setInfiniteScrollingView:(SVInfiniteScrollingView *)infiniteScrollingView {
    [self willChangeValueForKey:@"UIScrollViewInfiniteScrollingView"];
    objc_setAssociatedObject(self, &UIScrollViewInfiniteScrollingView,
                             infiniteScrollingView,
                             OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"UIScrollViewInfiniteScrollingView"];
}

- (SVInfiniteScrollingView *)infiniteScrollingView {
    return objc_getAssociatedObject(self, &UIScrollViewInfiniteScrollingView);
}

- (void)setShowsInfiniteScrolling:(BOOL)showsInfiniteScrolling {
    self.infiniteScrollingView.hidden = !showsInfiniteScrolling;
    
    if (showsInfiniteScrolling == NO) {
        if (self.infiniteScrollingView.isObserving) {
            [self removeObserver:self.infiniteScrollingView forKeyPath:@"contentOffset"];
            [self removeObserver:self.infiniteScrollingView forKeyPath:@"contentSize"];
            // If we ever disable inf. scrolling, we can reset the bottom inset here
            [self.infiniteScrollingView resetScrollViewContentInset];
            [self removeObserver:self.infiniteScrollingView forKeyPath:@"contentInset"];
            self.infiniteScrollingView.isObserving = NO;
        }
    } else {
        if (self.infiniteScrollingView.isObserving == NO) {
            [self addObserver:self.infiniteScrollingView forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self.infiniteScrollingView forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:self.infiniteScrollingView forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:nil];
            // This just sets a default bottom inset to always provide enough space at the bottom of the scroll view
            // to show the activity indicator
            [self.infiniteScrollingView setScrollViewContentInsetForInfiniteScrolling];
            self.infiniteScrollingView.isObserving = YES;
            
            [self.infiniteScrollingView setNeedsLayout];
            self.infiniteScrollingView.frame = CGRectMake(0, self.contentSize.height, self.infiniteScrollingView.bounds.size.width, SVInfiniteScrollingViewHeight);
        }
    }
}

- (BOOL)showsInfiniteScrolling {
    return !self.infiniteScrollingView.hidden;
}

@end

#pragma mark - SVInfiniteScrollingView Implementation

@implementation SVInfiniteScrollingView

// public properties
@synthesize infiniteScrollingHandler, activityIndicatorViewStyle;

@synthesize state = _state;
@synthesize scrollView = _scrollView;
@synthesize activityIndicatorView = _activityIndicatorView;

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // default styling values
        self.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.state = SVInfiniteScrollingStateStopped;
        self.enabled = YES;
        
        if ([[UIScreen mainScreen] bounds].size.height < 568) {
            self.offsetToTriggerInfiniteScrolling = 712; // There are 88 pixels less on a 3.5" screen
        } else {
            self.offsetToTriggerInfiniteScrolling = 800;
        }
    }
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (self.superview && newSuperview == nil) {
        UIScrollView *scrollView = (UIScrollView *)self.superview;
        if (scrollView.showsInfiniteScrolling) {
            if (self.isObserving) {
                [scrollView removeObserver:self forKeyPath:@"contentOffset"];
                [scrollView removeObserver:self forKeyPath:@"contentSize"];
                [scrollView removeObserver:self forKeyPath:@"contentInset"];
                self.isObserving = NO;
            }
        }
    }
}

#pragma mark - Content Insets

- (void)resetScrollViewContentInset {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    currentInsets.bottom -= SVInfiniteScrollingViewHeight;
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInsetForInfiniteScrolling {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    currentInsets.bottom += SVInfiniteScrollingViewHeight;
    [self setScrollViewContentInset:currentInsets];
}

- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset {
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.scrollView.contentInset = contentInset;
                     }
                     completion:NULL];
}

#pragma mark - KVO Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentOffset"]) {
        [self scrollViewDidScroll:[[change valueForKey:NSKeyValueChangeNewKey] CGPointValue]];
    } else if ([keyPath isEqualToString:@"contentSize"]) {
        [self layoutSubviews];
        self.frame = CGRectMake(0, self.scrollView.contentSize.height, self.bounds.size.width, SVInfiniteScrollingViewHeight);
    } else if ([keyPath isEqualToString:@"contentInset"]) {
        //NSLog(@"Content inset (top, left, bottom, right) changed to %@", NSStringFromUIEdgeInsets(self.scrollView.contentInset));
    }
}

- (void)scrollViewDidScroll:(CGPoint)contentOffset {
    if (contentOffset.y <= 0) { // Negative means pull-to-refresh
        return;
    }
    
    if (self.enabled && self.state == SVInfiniteScrollingStateStopped && [self didReachTriggerThreshold]) {
        [self startAnimating];
    } else if (self.state == SVInfiniteScrollingStateLoading && [self didReachTriggerThreshold] ) {
        [self stopAnimating];
    }
}

- (BOOL)didReachTriggerThreshold {
    if (self.state == SVInfiniteScrollingStateLoading) {
        return NO;
    }
    
    float y = self.scrollView.contentOffset.y + self.scrollView.bounds.size.height - self.scrollView.contentInset.bottom;
    float h = self.scrollView.contentSize.height;
    return (y > h - self.offsetToTriggerInfiniteScrolling);
}

#pragma mark - Getters

- (UIActivityIndicatorView *)activityIndicatorView {
    if(!_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activityIndicatorView.hidesWhenStopped = YES;
        [self addSubview:_activityIndicatorView];
    }
    return _activityIndicatorView;
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle {
    return self.activityIndicatorView.activityIndicatorViewStyle;
}

#pragma mark - Setters

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)viewStyle {
    self.activityIndicatorView.activityIndicatorViewStyle = viewStyle;
}

#pragma mark - Triggers

- (void)triggerRefresh {
    self.state = SVInfiniteScrollingStateLoading;
}

- (void)startAnimating{
    self.state = SVInfiniteScrollingStateLoading;
}

- (void)stopAnimating {
    self.state = SVInfiniteScrollingStateStopped;
}

- (void)setState:(SVInfiniteScrollingState)newState {
    if (_state == newState) {
        return;
    }
    
    _state = newState;
    
    CGRect viewBounds = [self.activityIndicatorView bounds];
    CGPoint origin = CGPointMake(roundf((self.bounds.size.width - viewBounds.size.width) / 2), roundf((self.bounds.size.height - viewBounds.size.height) / 2));
    [self.activityIndicatorView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
    
    switch (newState) {
        case SVInfiniteScrollingStateStopped:
            [self.activityIndicatorView stopAnimating];
            break;
            
        case SVInfiniteScrollingStateLoading:
            [self.activityIndicatorView startAnimating];
            break;
    }
    
    if (self.enabled && newState == SVInfiniteScrollingStateLoading && self.infiniteScrollingHandler) {
        self.infiniteScrollingHandler();
    }
}

@end
