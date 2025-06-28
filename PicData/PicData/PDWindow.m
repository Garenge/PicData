//
//  PDWindow.m
//  PicData
//
//  Created by Garenge on 2025/6/28.
//  Copyright © 2025 garenge. All rights reserved.
//

#import "PDWindow.h"

@implementation PDWindow

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews {
    
    // pan gesture to recognize mouse-wheel scrolling (zoom)
    UIPanGestureRecognizer * scrollWheelGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleScrollWheelGesture:)];
    scrollWheelGesture.allowedScrollTypesMask = UIScrollTypeMaskDiscrete;   // only accept scroll-wheel, not track-pad
    scrollWheelGesture.maximumNumberOfTouches = 0;
    [self addGestureRecognizer:scrollWheelGesture];
    
}

- (void)handleScrollWheelGesture:(UIPanGestureRecognizer *)pan
{
    CGPoint delta = [pan translationInView:self];
    CGFloat zoom = (1000 + delta.y) / 1000;
//    [self adjustZoomBy:zoom];
    
    NSLog(@"======== 鼠标滚动1: %@", NSStringFromCGPoint(delta));
}

@end
