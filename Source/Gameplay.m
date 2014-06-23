//
//  Gameplay.m
//  PeevedPenguins
//
//  Created by Mark on 6/13/14.
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "Gameplay.h"
#import "Penguin.h"

static const float MIN_SPEED = 5.f;
// Start at level 1
int nextLevel = 1;

@implementation Gameplay
{
    CCPhysicsNode *_physicsNode;
    CCNode *_pullbackNode;
    CCNode *_mouseJointNode;
    CCNode *_catapultArm;
    CCNode *_catapult;
    CCNode *_levelNode;
    CCNode *_contentNode;
    Penguin *_currentPenguin;
    CCPhysicsJoint *_penguinCatapultJoint;
    CCPhysicsJoint *_catapultJoint;
    CCPhysicsJoint *_pullbackJoint;
    CCPhysicsJoint *_mouseJoint;
    CCAction *_followPenguin;
    int deadSeals;
}

// is called when CCB file has completed loading
- (void)didLoadFromCCB
{
    // initialize number of dead seals
    deadSeals = 0;
    
    // Create string in order to load current/next levels
    NSString *levelString = [NSString stringWithFormat:@"Levels/Level%i",nextLevel];
    
    // tell this scene to accept touches
    self.userInteractionEnabled = TRUE;
    
    //Load the level
    CCScene *level = [CCBReader loadAsScene:levelString];
    [_levelNode addChild: level];
    
    // visualize physics bodies & joints for DEBUGGING PHYSICS
    //_physicsNode.debugDraw = TRUE;
    
    // catapultArm and catapult shall not collide
    [_catapultArm.physicsBody setCollisionGroup:_catapult];
    [_catapult.physicsBody setCollisionGroup:_catapult];
    
    // create a joint to connect the catapult arm with the catapult
    _catapultJoint = [CCPhysicsJoint connectedPivotJointWithBodyA:_catapultArm.physicsBody bodyB:_catapult.physicsBody anchorA:_catapultArm.anchorPointInPoints];
    
    // nothing shall collide with the invisible nodes
    _pullbackNode.physicsBody.collisionMask = @[];
    _mouseJointNode.physicsBody.collisionMask = @[];

    // create a spring joint for bringing arm in upright position and snapping back when player shoots
    _pullbackJoint = [CCPhysicsJoint connectedSpringJointWithBodyA:_pullbackNode.physicsBody bodyB:_catapultArm.physicsBody anchorA:ccp(0, 0) anchorB:ccp(34, 138) restLength:60.f stiffness:500.f damping:40.f];
    
    //sign up physicsNode as collision delegate
    _physicsNode.collisionDelegate = self;
    
    //set up the seal's collision type
    self.physicsBody.collisionType = @"seal";
}

// called on every touch in this scene
-(void) touchBegan:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint touchLocation = [touch locationInNode:_contentNode];
    
    // start catapult dragging when a touch inside of the catapult arm occurs
    if (CGRectContainsPoint([_catapultArm boundingBox], touchLocation))
    {
        // move the mouseJointNode to the touch position
        _mouseJointNode.position = touchLocation;
        
        // setup a spring joint between the mouseJointNode and the catapultArm
        _mouseJoint = [CCPhysicsJoint connectedSpringJointWithBodyA:_mouseJointNode.physicsBody bodyB:_catapultArm.physicsBody anchorA:ccp(0, 0) anchorB:ccp(34, 138) restLength:0.f stiffness:3000.f damping:300.f];
        
        // create a penguin from the ccb-file
        _currentPenguin = (Penguin*)[CCBReader load:@"Penguin"];
        
        // initially position it on the scoop. 34,138 is the position in the node space of the _catapultArm
        CGPoint penguinPosition = [_catapultArm convertToWorldSpace:ccp(34, 138)];
        
        // transform the world position to the node space to which the penguin will be added (_physicsNode)
        _currentPenguin.position = [_physicsNode convertToNodeSpace:penguinPosition];
        
        // add it to the physics world
        [_physicsNode addChild:_currentPenguin];
        
        // we don't want the penguin to rotate in the scoop
        _currentPenguin.physicsBody.allowsRotation = FALSE;
        
        // create a joint to keep the penguin fixed to the scoop until the catapult is released
        _penguinCatapultJoint = [CCPhysicsJoint connectedPivotJointWithBodyA:_currentPenguin.physicsBody bodyB:_catapultArm.physicsBody anchorA:_currentPenguin.anchorPointInPoints];
    }
}

- (void)launchPenguin
{
    // loads the Penguin.ccb we have set up in Spritebuilder
    CCNode* penguin = [CCBReader load:@"Penguin"];
    // position the penguin at the bowl of the catapult
    penguin.position = ccpAdd(_catapultArm.position, ccp(16, 50));
    
    // add the penguin to the physicsNode of this scene (because it has physics enabled)
    [_physicsNode addChild:penguin];
    
    // manually create & apply a force to launch the penguin
    CGPoint launchDirection = ccp(1, 0);
    CGPoint force = ccpMult(launchDirection, 2000);
    [penguin.physicsBody applyForce:force];
    
    // ensure followed object is in visible are when starting
    self.position = ccp(0, 0);
    CCActionFollow *follow = [CCActionFollow actionWithTarget:penguin worldBoundary:self.boundingBox];
    [_contentNode runAction:follow];
}

- (void)retry
{
    // reload this level
    deadSeals = 0;
    [[CCDirector sharedDirector] replaceScene: [CCBReader loadAsScene:@"Gameplay"]];
}

- (void)touchMoved:(UITouch *)touch withEvent:(UIEvent *)event
{
    // whenever touches move, update the position of the mouseJointNode to the touch position
    CGPoint touchLocation = [touch locationInNode:_contentNode];
    _mouseJointNode.position = touchLocation;
}

- (void)releaseCatapult
{
    if (_mouseJoint != nil)
    {
        // releases the joint and lets the catapult snap back
        [_mouseJoint invalidate];
        _mouseJoint = nil;
        
        // releases the joint and lets the penguin fly
        [_penguinCatapultJoint invalidate];
        _penguinCatapultJoint = nil;
        
        // after snapping rotation is fine
        _currentPenguin.physicsBody.allowsRotation = TRUE;
        
        // follow the flying penguin
        _followPenguin = [CCActionFollow actionWithTarget:_currentPenguin worldBoundary:self.boundingBox];
        [_contentNode runAction:_followPenguin];
        
        _currentPenguin.launched = TRUE;
    }
}

-(void) touchEnded:(UITouch *)touch withEvent:(UIEvent *)event
{
    // when touches end, meaning the user releases their finger, release the catapult
    [self releaseCatapult];
}

-(void) touchCancelled:(UITouch *)touch withEvent:(UIEvent *)event
{
    // when touches are cancelled, meaning the user drags their finger off the screen or onto something else, release the catapult
    [self releaseCatapult];
}

-(void)ccPhysicsCollisionPostSolve:(CCPhysicsCollisionPair *)pair seal:(CCNode *)nodeA wildcard:(CCNode *)nodeB
{
    float energy = [pair totalKineticEnergy];
    
    // if energy is large enough, remove the seal
    if (energy > 5000.f)
    {
        [self sealRemoved:nodeA];
    }
}

- (void)sealRemoved:(CCNode *)seal
{
    // load particle effect
    CCParticleSystem *explosion = (CCParticleSystem *)[CCBReader load:@"SealExplosion"];
    
    // make the particle effect clean itself up, once it is completed
    explosion.autoRemoveOnFinish = TRUE;
    
    // place the particle effect on the seals position
    explosion.position = seal.position;
    
    // add the particle effect to the same node the seal is on
    [seal.parent addChild:explosion];
    
    // finally, remove the destroyed seal
    [seal removeFromParent];
    
    deadSeals++;
}

- (void)update:(CCTime)delta
{
    // If all seals are dead
    if (deadSeals == 5) {
        
        // Increment nextLevel
        nextLevel++;
        
        // Remove the current level from the node
        [_levelNode removeAllChildren];
        
        // Replace the scene with Gameplay again
        [[CCDirector sharedDirector] replaceScene: [CCBReader loadAsScene:@"Gameplay"]];
        
        // Reset deadSeals to 0
        deadSeals = 0;
    }
    
    if(_currentPenguin.launched)
    {
        // if speed is below minimum speed, assume this attempt is over
        if (ccpLength(_currentPenguin.physicsBody.velocity) < MIN_SPEED)
        {
            [self nextAttempt];
            return;
        }
    
        int xMin = _currentPenguin.boundingBox.origin.x;
    
        if (xMin < self.boundingBox.origin.x)
        {
            [self nextAttempt];
            return;
        }
    
        int xMax = xMin + _currentPenguin.boundingBox.size.width;
    
        if (xMax > (self.boundingBox.origin.x + self.boundingBox.size.width))
        {
            [self nextAttempt];
            return;
        }
    }
}

- (void)nextAttempt
{
    // Set the current penguing to nil
    _currentPenguin = nil;
    // Stop following the penguin
    [_contentNode stopAction:_followPenguin];
    
    // Move back to the beginning of the Gameplay
    CCActionMoveTo *actionMoveTo = [CCActionMoveTo actionWithDuration:1.f position:ccp(0, 0)];
    [_contentNode runAction:actionMoveTo];
}

@end
