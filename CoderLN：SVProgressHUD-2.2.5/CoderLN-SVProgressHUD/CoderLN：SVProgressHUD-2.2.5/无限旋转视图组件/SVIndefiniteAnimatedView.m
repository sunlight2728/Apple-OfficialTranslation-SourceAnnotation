//
//  SVIndefiniteAnimatedView.m
//  SVProgressHUD, https://github.com/SVProgressHUD/SVProgressHUD
//
//  Copyright (c) 2014-2018 Guillaume Campagna. All rights reserved.
//

#import "SVIndefiniteAnimatedView.h"
#import "SVProgressHUD.h"

@interface SVIndefiniteAnimatedView ()

// CAShapeLayer 形状图层，indefiniteAnimatedLayer是一个圆形layer
// mask遮罩属性是一个以特定图片为内容的layer (CALayer * maskLayer)
@property (nonatomic, strong) CAShapeLayer *indefiniteAnimatedLayer;

@end

@implementation SVIndefiniteAnimatedView

/**
 显示原理：
 该方法在父视图将要发生改变(add/remove)时会被系统调用, 该方法默认实现没有进行任何操作,
      子类可以覆盖该方法以执行一些额外的操作, 当视图被add时, newSuperview为父视图; 当视图被remove时, newSuperview为nil
 */
- (void)willMoveToSuperview:(UIView*)newSuperview {
    // 当父视图存在时(即视图被add时), 将indefiniteAnimatedLayer添加为self.layer的子layer
    if (newSuperview) {
        [self layoutAnimatedLayer];
    }
    
    // 当父视图不存在时(即视图被remove时), 将indefiniteAnimatedLayer从self.layer中移除
    else {
        [_indefiniteAnimatedLayer removeFromSuperlayer];
        _indefiniteAnimatedLayer = nil;
    }
}

- (void)layoutAnimatedLayer {
    CALayer *layer = self.indefiniteAnimatedLayer;
    [self.layer addSublayer:layer];
    
    CGFloat widthDiff = CGRectGetWidth(self.bounds) - CGRectGetWidth(layer.bounds);
    CGFloat heightDiff = CGRectGetHeight(self.bounds) - CGRectGetHeight(layer.bounds);
    layer.position = CGPointMake(CGRectGetWidth(self.bounds) - CGRectGetWidth(layer.bounds) / 2 - widthDiff / 2, CGRectGetHeight(self.bounds) - CGRectGetHeight(layer.bounds) / 2 - heightDiff / 2);
}


/**
 说明：
 关于 mask 是这样的：遮罩的不透明部分和被遮罩的layer的重叠部分的 layer 才会去渲染。
 
 1         2
      |
 - - - - - -
 开始* |
 3         4
 
 
 */
- (CAShapeLayer*)indefiniteAnimatedLayer {
    if(!_indefiniteAnimatedLayer) {
        // 首先无限旋转的动画是一个圆，所以要先确定圆心
        CGPoint arcCenter = CGPointMake(self.radius+self.strokeThickness/2+5, self.radius+self.strokeThickness/2+5);
        
        // 确定画圆这个动画的起始位置和结束位置，从 M_PI*3/2 到 M_PI/2+M_PI*5 实际上是两个360°，下面解释为什么要画两圈。270 - 990
        UIBezierPath* smoothedPath = [UIBezierPath bezierPathWithArcCenter:arcCenter radius:self.radius startAngle:(CGFloat) (M_PI*3/2) endAngle:(CGFloat) (M_PI/2+M_PI*5) clockwise:YES];
        
         //创建图层，写到这里我们应该得到的如下图所示（特意放大了 HUD 的尺寸）
        _indefiniteAnimatedLayer = [CAShapeLayer layer];
        _indefiniteAnimatedLayer.contentsScale = [[UIScreen mainScreen] scale];
        _indefiniteAnimatedLayer.frame = CGRectMake(0.0f, 0.0f, arcCenter.x*2, arcCenter.y*2);
        _indefiniteAnimatedLayer.fillColor = [UIColor clearColor].CGColor;
        _indefiniteAnimatedLayer.strokeColor = self.strokeColor.CGColor;
        _indefiniteAnimatedLayer.lineWidth = self.strokeThickness;
        _indefiniteAnimatedLayer.lineCap = kCALineCapRound;
        _indefiniteAnimatedLayer.lineJoin = kCALineJoinBevel;
        _indefiniteAnimatedLayer.path = smoothedPath.CGPath;
        
        CALayer *maskLayer = [CALayer layer];
        
        NSBundle *bundle = [NSBundle bundleForClass:[SVProgressHUD class]];
        NSURL *url = [bundle URLForResource:@"SVProgressHUD" withExtension:@"bundle"];
        NSBundle *imageBundle = [NSBundle bundleWithURL:url];
        
        NSString *path = [imageBundle pathForResource:@"angle-mask" ofType:@"png"];
        
        maskLayer.contents = (__bridge id)[[UIImage imageWithContentsOfFile:path] CGImage];
        maskLayer.frame = _indefiniteAnimatedLayer.bounds;
        // 将maskLayer作为indefiniteAnimatedLayer的mask遮罩属性, 便实现了无限指示器效果
        _indefiniteAnimatedLayer.mask = maskLayer;
        
        
        
        
        NSTimeInterval animationDuration = 1;
        CAMediaTimingFunction *linearCurve = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        
        // 通过CABasicAnimation针对maskLayer的transform.rotation添加动画, 使其不断地顺时针进行旋转
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
        animation.fromValue = (id) 0;
        animation.toValue = @(M_PI*2); 
        animation.duration = animationDuration;
        animation.timingFunction = linearCurve;
        animation.removedOnCompletion = NO;
        animation.repeatCount = INFINITY;
        animation.fillMode = kCAFillModeForwards;
        animation.autoreverses = NO;
        [_indefiniteAnimatedLayer.mask addAnimation:animation forKey:@"rotate"];
        
        
        /**
          还记得 _indefiniteAnimatedLayer 的 path 是两个360°吗？
          因为 strokeStart 和 strokeEnd 的动画都是0.5的差距（取值范围0 ~ 1）
          所以0.5的比例就是一圈的距离，那么这条线的长度就刚好是一个360°
         */
        // 通过CAAnimationGroup为indefiniteAnimatedLayer的strokeStart和strokeEnd添加动画, 使其不断地顺时针进行旋转, 同时保证拥有一个不变的缺口
        CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
        animationGroup.duration = animationDuration;
        animationGroup.repeatCount = INFINITY;
        animationGroup.removedOnCompletion = NO;
        animationGroup.timingFunction = linearCurve;
        
        CABasicAnimation *strokeStartAnimation = [CABasicAnimation animationWithKeyPath:@"strokeStart"];
        // strokeStart 从为什么从0.015开始呢？因如果line 很粗的情况下（用户可以自定义）
        // _indefiniteAnimatedLayer.lineCap = kCALineCapRound; line 的头部是圆的，会超出它本来的界限
        strokeStartAnimation.fromValue = @0.015;
        strokeStartAnimation.toValue = @0.515;
        
        CABasicAnimation *strokeEndAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        //strokeEnd 从0.485开始，保证与strokeStart 有一段距离，这样才能看到 line 的圆角
        //如果直接写成0.5 那么 line 就连在了一起看不出来 line 的头部在哪里
        strokeEndAnimation.fromValue = @0.485;
        strokeEndAnimation.toValue = @0.985;
        
        animationGroup.animations = @[strokeStartAnimation, strokeEndAnimation];
        [_indefiniteAnimatedLayer addAnimation:animationGroup forKey:@"progress"];
        
    }
    return _indefiniteAnimatedLayer;
}

- (void)setFrame:(CGRect)frame {
    if(!CGRectEqualToRect(frame, super.frame)) {
        [super setFrame:frame];
        
        if(self.superview) {
            [self layoutAnimatedLayer];
        }
    }
    
}

- (void)setRadius:(CGFloat)radius {
    if(radius != _radius) {
        _radius = radius;
        
        [_indefiniteAnimatedLayer removeFromSuperlayer];
        _indefiniteAnimatedLayer = nil;
        
        if(self.superview) {
            [self layoutAnimatedLayer];
        }
    }
}

- (void)setStrokeColor:(UIColor*)strokeColor {
    _strokeColor = strokeColor;
    _indefiniteAnimatedLayer.strokeColor = strokeColor.CGColor;
}

- (void)setStrokeThickness:(CGFloat)strokeThickness {
    _strokeThickness = strokeThickness;
    _indefiniteAnimatedLayer.lineWidth = _strokeThickness;
}

/**
 大小原理：
 当调用sizeToFit方法时, 系统会自动调用如下方法, 并设置自身大小
 */
- (CGSize)sizeThatFits:(CGSize)size {
    return CGSizeMake((self.radius+self.strokeThickness/2+5)*2, (self.radius+self.strokeThickness/2+5)*2);
}

@end
