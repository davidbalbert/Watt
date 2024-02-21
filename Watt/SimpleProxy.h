//
//  BaseOutlineViewDelegateProxy.h
//  Watt
//
//  Created by David Albert on 1/9/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimpleProxy : NSProxy
- (instancetype)initWithTarget:(id<NSObject>)target;
@end

NS_ASSUME_NONNULL_END
