#import <Foundation/Foundation.h>

@interface NSNull (Safe)
- (float)floatValue;
- (double)doubleValue;
- (NSInteger)integerValue;
- (int)intValue;
- (long long)longLongValue;
- (BOOL)boolValue;
- (NSUInteger)length;
- (NSUInteger)count;
- (id)objectForKey:(id)key;
- (id)objectAtIndex:(NSUInteger)index;
- (BOOL)isEqualToString:(NSString *)aString;
- (NSString *)lowercaseString;
- (NSString *)uppercaseString;
- (BOOL)hasPrefix:(NSString *)str;
- (BOOL)hasSuffix:(NSString *)str;
- (id)firstObject;
- (id)lastObject;
@end

@interface NSArray (Safe)
- (id)firstObject;
- (NSUInteger)length;
- (NSInteger)integerValue;
- (BOOL)boolValue;
@end

@interface NSDictionary (Safe)
- (NSUInteger)length;
- (NSInteger)integerValue;
- (BOOL)boolValue;
@end

@interface NSNumber (Safe)
- (NSUInteger)length;
@end
