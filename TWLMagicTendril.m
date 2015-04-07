//
//  TWLMagicTendril.m
//  SpawningLetterBalls
//
//  Created by Greg on 2014-12-11.
//  Copyright (c) 2014 Tasty Morsels. All rights reserved.
//

#import "TWLMagicTendril.h"
#import "TWLBall.h"
#import "TWLColourPalette.h"

#define kFrameDuration 0.04 //25 frames per second

#define kPathSteps 25  //maximum number of steps taken in making the tendril
#define kStepDistance 6.0 //length of each step; the direction is that of the net force on the walker from source and sink
#define kSinkMass 5.0 //Source is weighted 1.0; this is the relative sink weight in the inverse-square law force calculation


#define kMaxSep 400.0  //beyond this inter-ball distance, the degree of waviness does not change

#define kDeviationMax (20.0 * 0.01745329) //convert degrees to radians
#define kDevChangeMax (5.0 * 0.01745329)


#define kPadding 5 //Pad out the bitmap to allow for line width of stroke


@interface TWLMagicTendril ()
@property (nonatomic,weak) TWLBall* source;
@property (nonatomic,weak) TWLBall* sink;
@property NSMutableArray* deviations; //not nonatomic; want to make sure it is accessed in a stable state;
@property (nonatomic, getter=isTouchingTarget) BOOL touchingTarget;

@end
@implementation TWLMagicTendril{
    
    NSTimeInterval lastUpdate;
    
    float theta; //tendril exits source at this angle relative to axis between source and sink (target)
    float alpha; //angle between source-sink axis and x-axis in parent coord system
    CGPoint pTarget;
    CGPoint origin;
    int maxPathSteps;
    
    BOOL rebuildDeviationArray;
    float sepWhenDeviationArrayLastRebuilt;

    
    int deviationOffset;
    int myRandomOffset;
    float myRandomDeviationFactor;
    
    int withinRangeOfTarget;
    
}

-(id)initWithSource:(TWLBall*)source andSink:(TWLBall*)sink andAngle:(float)angle{
    self = [super initWithColor:[UIColor yellowColor] size:CGSizeMake(1,1)];
    if (self){
        
        self.name = [TWLMagicTendril name];
        
        if (source != nil && sink != nil){
            _source = source;
            _sink = sink;
            
            self->myRandomOffset = arc4random_uniform(10);
            self->myRandomDeviationFactor = 0.6 + 0.8 * (float)rand()/RAND_MAX;
            
            self->withinRangeOfTarget = 0.8 * ( _sink.diameter / 2.0 );
            
            _deviations = [NSMutableArray new];
            self->deviationOffset = 0;
            
            [self buildDeviationArray];
            self->rebuildDeviationArray = NO;
            
            self->maxPathSteps = 1;
            
            self->theta = angle;
            
            
            [self updateTargetAndAlpha];
            @autoreleasepool {
                SKTexture* myTexture = [self makeTexture];
                self.size = myTexture.size;
                self.texture = myTexture;
            }
          
            self.zPosition = -100;
            
            //COLOR
            self.colorBlendFactor = 1.0;
            self.color = TWLCOLOUR_ULTRAMARINE;
            
            
            self.anchorPoint = CGPointMake( self->origin.x / self.size.width, self->origin.y / self.size.height);
            
            
            self.zRotation = self->alpha ;
            
            self->lastUpdate = [[NSDate date] timeIntervalSince1970];
            
            _touchingTarget = NO;
            
        }
    }
    return self;
}
-(void)dealloc{
    NSLog(@"TWLMagicTendril dealloc");
}

-(void)update{
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if ( now - self->lastUpdate > kFrameDuration){
        
        if (self.sink != nil && self.source != nil){
            
            if (self->rebuildDeviationArray == YES){
                [self buildDeviationArray];
            }
            
            if (self->maxPathSteps < (kPathSteps-1)){
                ++self->maxPathSteps;
            }
            
            [self updateTargetAndAlpha];
            SKTexture* myTexture = [self makeTexture];
            self.size = myTexture.size;
            self.texture = myTexture;
            self.anchorPoint = CGPointMake( self->origin.x / self.size.width, self->origin.y / self.size.height);
            self.zRotation = self->alpha;
            
            
        }
        
        self->lastUpdate = now;
    }
}
-(float)computeDistanceSourceToSink{
    float result = kMaxSep + 1.0;
    if (self.sink != nil && self.source != nil){
        float dX = self.sink.position.x - self.source.position.x;
        float dY = self.sink.position.y - self.source.position.y;
        result = sqrtf( dX*dX + dY*dY);
    }
    return result;
}
-(void)updateTargetAndAlpha{
    CGPoint p1 = [self.source position]; //in scene coordinates
    CGPoint p2 = [self.sink position];
    self->pTarget = CGPointMake(p2.x - p1.x, p2.y - p1.y); //puts source at origin
    self->alpha = atan2f(self->pTarget.y, self->pTarget.x);
    self->pTarget = CGPointApplyAffineTransform(self->pTarget, CGAffineTransformMakeRotation(-self->alpha)); //put target on x-axis in source coords
}

-(SKTexture*)makeTexture{
    
    SKTexture* result;
    
    if (self.source != nil && self.sink != nil) {
        
        //NSLog(@"makeTexture for %@ tendril", [self.source who]);
        
        UIBezierPath* path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(0, 0)];
        CGPoint p = CGPointMake(kStepDistance*cosf(self->theta), kStepDistance*sinf(self->theta));
        [path addLineToPoint:p];
        int maxSteps = self->maxPathSteps;
        for (int i=0; i<maxSteps; i++){
            
            float distPtoS = sqrtf(p.x*p.x + p.y*p.y);
            float distPtoS2 = distPtoS * distPtoS;
            CGVector fS = CGVectorMake(p.x/distPtoS2, p.y/distPtoS2);
            
            CGVector rPtoT = CGVectorMake(self->pTarget.x-p.x, -p.y);
            float distPtoT = sqrtf(rPtoT.dx*rPtoT.dx + rPtoT.dy*rPtoT.dy);
            
            if (distPtoT < self->withinRangeOfTarget) {
                self.touchingTarget = YES;
                break;
            } else {
                self.touchingTarget = NO;
            }
            
            CGVector fNet = fS;
            if (distPtoT / distPtoS > 0.01){
                //include force from target in computing net force
                float distPtoT2 = distPtoT * distPtoT;
                CGVector fT = CGVectorMake(kSinkMass*rPtoT.dx/distPtoT2, kSinkMass*rPtoT.dy/distPtoT2);
                fNet = CGVectorMake(fNet.dx+fT.dx, fNet.dy+fT.dy);
            }
            
            float alphaFNet = atan2f(fNet.dy, fNet.dx);
           
            int maxIndex = (int)([self.deviations count] - 1) ;
            int index = ((i + self->deviationOffset + self->myRandomOffset) % maxIndex);
            
            float ramp = (float)i / maxSteps;
            float angleWithDeviation = alphaFNet + ramp * [[self.deviations objectAtIndex:index] floatValue];
            p = CGPointMake(p.x + kStepDistance*cosf(angleWithDeviation), p.y+kStepDistance*sinf(angleWithDeviation));
            
           
            [path addLineToPoint:p];
            
        }
        
        self->deviationOffset += 1;
        if (self->deviationOffset >= [self.deviations count]) self->deviationOffset = 0;

        
        CGRect pathBounds = [path bounds]; //bounding rectangle of path in **points**
        self->origin.x = -pathBounds.origin.x;
        self->origin.y = -pathBounds.origin.y;
        
        
        [path applyTransform:CGAffineTransformMakeTranslation(self->origin.x, self->origin.y)];
        pathBounds = [path bounds];
        
        
        //adjust origin for padding
        self->origin.x += kPadding;
        self->origin.y += kPadding;
        
        CGSize newSize = CGSizeMake((pathBounds.size.width>0 ? pathBounds.size.width + 2 * kPadding : 1 + 2*kPadding),
                                    (pathBounds.size.height>0 ? pathBounds.size.height + 2 * kPadding : 1 + 2*kPadding)  );
        [path applyTransform:CGAffineTransformMakeTranslation(kPadding, kPadding)];
        
        UIGraphicsBeginImageContextWithOptions(newSize, NO, 0); //last arg=0 means use scale on current device
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetLineWidth(context, 2.0);
        [[UIColor whiteColor] setStroke];
        CGContextAddPath(context, [path CGPath]);
        CGContextStrokePath(context);
        
               
        UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
       
        //Flip image
        
        CGImageRef im = image.CGImage;
        float scaleNow = image.scale;
        CGSize sz = CGSizeMake(CGImageGetWidth(im)/scaleNow, CGImageGetHeight(im)/scaleNow);
        UIGraphicsBeginImageContextWithOptions(sz, NO, 0);
        CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, sz.width, sz.height), im);
        
        UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        
        result = [SKTexture textureWithImage:newImage];

        
    }
    
    return result;
}


-(void)buildDeviationArray{
    
    float sep = [self computeDistanceSourceToSink];
    
    if (sep < kMaxSep || self->sepWhenDeviationArrayLastRebuilt < kMaxSep){
        
        float maxDev = kDeviationMax;
        float deltaDev = kDevChangeMax;
        
        self->sepWhenDeviationArrayLastRebuilt = sep;
        
        
        if (sep < kMaxSep){
            float sepRatio = sep / kMaxSep;
            maxDev = sepRatio * kDeviationMax;
            deltaDev = sepRatio * kDevChangeMax;
        }
        
        deltaDev = deltaDev * self->myRandomDeviationFactor;
        
        float testDeltaDev = deltaDev;
        float dev = 0.0;
        dev += testDeltaDev;
        int stepsToZeroCrossing = 1;
        while (dev >= 0){
            if (dev >= maxDev){
                testDeltaDev = -deltaDev;
            }
            dev += testDeltaDev;
            ++stepsToZeroCrossing;
        }
        
        int patternLength = 1 + 2 * stepsToZeroCrossing;
        
        dev = 0.0;
        [self.deviations removeAllObjects];
        for (int i=0; i < patternLength; i++){
            [self.deviations addObject:[NSNumber numberWithFloat:(self->myRandomDeviationFactor * dev) ]];
            //Flip deltaDev when reach extrema
            if (dev >= maxDev){
                deltaDev = - deltaDev;
            }
            if (dev <= -maxDev){
                deltaDev = - deltaDev;
            }
            dev += deltaDev;
        }
    }

    self->rebuildDeviationArray = NO;
}

-(void)terminate{
    [self runAction:[SKAction sequence:@[[SKAction fadeOutWithDuration:.1],[SKAction removeFromParent]]]];
}

+(NSString*)name{
    return @"magicTendril";
}

@end
