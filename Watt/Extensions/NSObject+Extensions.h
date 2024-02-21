//
//  NSObject+Extensions.h
//  Watt
//
//  Created by David Albert on 2/7/24.
//

#ifndef NSObject_Extensions_h
#define NSObject_Extensions_h

#import <Foundation/Foundation.h>

@interface NSObject (Extensions)

- (id)performSelector:(SEL)sel withObject:(id)obj1 withObject:(id)obj2 withObject:(id)obj3;

@end

#endif /* NSObject_Extensions_h */
