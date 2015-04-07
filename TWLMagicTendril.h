//
//  TWLMagicTendril.h
//  SpawningLetterBalls
//
//  Created by Greg on 2014-12-11.
//  Copyright (c) 2014 Tasty Morsels. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>
@class TWLBall;

@interface TWLMagicTendril : SKSpriteNode

@property (nonatomic, readonly, getter=isTouchingTarget) BOOL touchingTarget;

-(id)initWithSource:(TWLBall*)source andSink:(TWLBall*)sink andAngle:(float)theta;
-(void)update;
-(void)terminate;
+(NSString*)name;

@end
