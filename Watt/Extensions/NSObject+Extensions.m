//
//  NSObject+Extensions.m
//  Watt
//
//  Created by David Albert on 2/7/24.
//


#import "NSObject+Extensions.h"
#import <objc/message.h>

@implementation NSObject (Extensions)

// Implementation adapted from performSelector:withObject:withObject: in https://github.com/apple-oss-distributions/objc4
- (id)performSelector:(SEL)sel withObject:(id)obj1 withObject:(id)obj2 withObject:(id)obj3 {
    if (!sel) [self doesNotRecognizeSelector:sel];
    return ((id(*)(id, SEL, id, id, id))objc_msgSend)(self, sel, obj1, obj2, obj3);
}

@end
