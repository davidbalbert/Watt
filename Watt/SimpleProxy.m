//
//  SimpleProxy.m
//  Watt
//
//  Created by David Albert on 1/9/24.
//

#import "SimpleProxy.h"
#import <objc/runtime.h>

@interface SimpleProxy ()
@property (strong, nonatomic) id<NSObject> target;
@end

@implementation SimpleProxy

- (instancetype)initWithTarget:(id<NSObject>)target {
    if (self) {
        _target = target;
    }
    return self;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    [anInvocation invokeWithTarget:self.target];
    return;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    if ([self.target respondsToSelector:@selector(methodSignatureForSelector:)]) {
        return [(id)self.target methodSignatureForSelector:sel];
    }

    return nil;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return class_respondsToSelector([self class], aSelector) || [self.target respondsToSelector:aSelector];
}
@end
