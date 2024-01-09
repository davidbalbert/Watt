//
//  SimpleProxy.m
//  Watt
//
//  Created by David Albert on 1/9/24.
//

#import "SimpleProxy.h"

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
    NSLog(@"forwardInvocation %@", anInvocation);
    [anInvocation invokeWithTarget:self.target];
    return;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    NSLog(@"methodSignatureForSelector %@", NSStringFromSelector(sel));
    if ([self.target isKindOfClass:[NSObject class]]) {
        return [(NSObject *)self.target methodSignatureForSelector:sel];
    } else {
        return nil;
    }
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [super respondsToSelector:aSelector] || [self.target respondsToSelector:aSelector];
}
@end
