//
//  Seal.m
//  PeevedPenguins
//
//  Created by Mark on 6/13/14.
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "Seal.h"

@implementation Seal

//assign collision type to seal objects
- (void)didLoadFromCCB {
    self.physicsBody.collisionType = @"seal";
}

@end
