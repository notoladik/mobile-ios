#import "NSNull+Safe.h"

@implementation NSNull (Safe)

- (float)floatValue { return 0.0f; }
- (double)doubleValue { return 0.0; }
- (NSInteger)integerValue { return 0; }
- (int)intValue { return 0; }
- (long long)longLongValue { return 0LL; }
- (BOOL)boolValue { return NO; }
- (NSUInteger)length { return 0; }
- (NSUInteger)count { return 0; }
- (id)objectForKey:(id)key { return nil; }
- (id)objectAtIndex:(NSUInteger)index { return nil; }
- (BOOL)isEqualToString:(NSString *)aString { return NO; }
- (NSString *)lowercaseString { return @""; }
- (NSString *)uppercaseString { return @""; }
- (BOOL)hasPrefix:(NSString *)str { return NO; }
- (BOOL)hasSuffix:(NSString *)str { return NO; }
- (id)firstObject { return nil; }
- (id)lastObject { return nil; }

@end

@implementation NSArray (Safe)

- (NSUInteger)length {
    return 0;
}

- (NSInteger)integerValue {
    return 0;
}

- (BOOL)boolValue {
    return self.count > 0;
}

@end

@implementation NSDictionary (Safe)

- (NSUInteger)length {
    return 0;
}

- (NSInteger)integerValue {
    return 0;
}

- (BOOL)boolValue {
    return self.count > 0;
}

@end

@implementation NSNumber (Safe)

- (NSUInteger)length {
    return [[self stringValue] length];
}

@end
