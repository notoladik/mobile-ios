#import "VKEELVirtualMachine.h"
#import <math.h>

@implementation VKEELVirtualMachine

- (instancetype)init {
    self = [super init];
    if (self) {
        _variables = [NSMutableDictionary dictionary];
        [self resetDefaults];
    }
    return self;
}

- (void)resetDefaults {
    self.variables[@"pi"] = @(M_PI);
    self.variables[@"e"] = @(M_E);
    self.variables[@"zoom"] = @(1.0);
    self.variables[@"rot"] = @(0.0);
    self.variables[@"warp"] = @(0.0);
    self.variables[@"decay"] = @(0.97);
    self.variables[@"cx"] = @(0.5);
    self.variables[@"cy"] = @(0.5);
    self.variables[@"dx"] = @(0.0);
    self.variables[@"dy"] = @(0.0);
    self.variables[@"wave_r"] = @(1.0);
    self.variables[@"wave_g"] = @(1.0);
    self.variables[@"wave_b"] = @(1.0);
    self.variables[@"wave_a"] = @(0.8);
    self.variables[@"time"] = @(0.0);
    self.variables[@"bass"] = @(1.0);
    self.variables[@"mid"] = @(1.0);
    self.variables[@"treb"] = @(1.0);
    self.variables[@"frame"] = @(0.0);
    for (int i = 1; i <= 8; i++) {
        self.variables[[NSString stringWithFormat:@"q%d", i]] = @(0.0);
    }
}

- (void)setVariable:(NSString *)name value:(CGFloat)value {
    if (!name) return;
    self.variables[[name lowercaseString]] = @(value);
}

- (CGFloat)getVariable:(NSString *)name {
    if (!name) return 0.0;
    NSNumber *num = self.variables[[name lowercaseString]];
    return num ? [num doubleValue] : 0.0;
}

- (void)evaluateScript:(NSString *)script {
    if (!script || script.length == 0) return;
    
    NSArray *statements = [script componentsSeparatedByString:@";"];
    for (NSString *st in statements) {
        NSString *trimmed = [st stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) continue;
        
        NSRange eqRange = [trimmed rangeOfString:@"="];
        if (eqRange.location != NSNotFound) {
            NSString *varName = [[trimmed substringToIndex:eqRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSString *expr = [[trimmed substringFromIndex:eqRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            
            CGFloat val = [self evaluateExpression:expr];
            [self setVariable:varName value:val];
        } else {
            [self evaluateExpression:trimmed];
        }
    }
}

#pragma mark - Expression Evaluator (Shunting-Yard & RPN Math Engine)

- (CGFloat)evaluateExpression:(NSString *)expr {
    if (!expr || expr.length == 0) return 0.0;
    
    // Токенизация
    NSMutableArray *tokens = [self tokenize:expr];
    if (tokens.count == 0) return 0.0;
    
    // Преобразование в Reverse Polish Notation (RPN)
    NSArray *rpn = [self toRPN:tokens];
    
    // Вычисление RPN
    return [self evaluateRPN:rpn];
}

- (NSMutableArray *)tokenize:(NSString *)expr {
    NSMutableArray *tokens = [NSMutableArray array];
    NSInteger len = expr.length;
    NSInteger i = 0;
    
    while (i < len) {
        unichar c = [expr characterAtIndex:i];
        if (isspace(c)) {
            i++;
            continue;
        }
        
        if (c == '+' || c == '-' || c == '*' || c == '/' || c == '%' || c == '(' || c == ')' || c == ',') {
            [tokens addObject:[NSString stringWithCharacters:&c length:1]];
            i++;
        } else if (isdigit(c) || c == '.') {
            NSInteger start = i;
            while (i < len && (isdigit([expr characterAtIndex:i]) || [expr characterAtIndex:i] == '.')) {
                i++;
            }
            [tokens addObject:[expr substringWithRange:NSMakeRange(start, i - start)]];
        } else if (isalpha(c) || c == '_') {
            NSInteger start = i;
            while (i < len && (isalnum([expr characterAtIndex:i]) || [expr characterAtIndex:i] == '_')) {
                i++;
            }
            [tokens addObject:[expr substringWithRange:NSMakeRange(start, i - start)]];
        } else {
            i++;
        }
    }
    return tokens;
}

- (NSInteger)precedence:(NSString *)op {
    if ([op isEqualToString:@"+"] || [op isEqualToString:@"-"]) return 1;
    if ([op isEqualToString:@"*"] || [op isEqualToString:@"/"] || [op isEqualToString:@"%"]) return 2;
    return 0;
}

- (BOOL)isFunction:(NSString *)token {
    static NSSet *funcs = nil;
    if (!funcs) {
        funcs = [NSSet setWithObjects:@"sin", @"cos", @"tan", @"asin", @"acos", @"sqrt", @"abs", @"log", @"exp", @"min", @"max", @"sign", @"rand", @"if", nil];
    }
    return [funcs containsObject:[token lowercaseString]];
}

- (NSArray *)toRPN:(NSArray *)tokens {
    NSMutableArray *output = [NSMutableArray array];
    NSMutableArray *opStack = [NSMutableArray array];
    
    for (NSString *tok in tokens) {
        if ([tok isEqualToString:@","]) {
            while (opStack.count > 0 && ![[opStack lastObject] isEqualToString:@"("]) {
                [output addObject:[opStack lastObject]];
                [opStack removeLastObject];
            }
        } else if ([tok isEqualToString:@"("]) {
            [opStack addObject:tok];
        } else if ([tok isEqualToString:@")"]) {
            while (opStack.count > 0 && ![[opStack lastObject] isEqualToString:@"("]) {
                [output addObject:[opStack lastObject]];
                [opStack removeLastObject];
            }
            if (opStack.count > 0 && [[opStack lastObject] isEqualToString:@"("]) {
                [opStack removeLastObject];
            }
            if (opStack.count > 0 && [self isFunction:[opStack lastObject]]) {
                [output addObject:[opStack lastObject]];
                [opStack removeLastObject];
            }
        } else if ([self isFunction:tok]) {
            [opStack addObject:tok];
        } else if ([tok isEqualToString:@"+"] || [tok isEqualToString:@"-"] || [tok isEqualToString:@"*"] || [tok isEqualToString:@"/"] || [tok isEqualToString:@"%"]) {
            while (opStack.count > 0 && [self precedence:[opStack lastObject]] >= [self precedence:tok]) {
                [output addObject:[opStack lastObject]];
                [opStack removeLastObject];
            }
            [opStack addObject:tok];
        } else {
            // Число или переменная
            [output addObject:tok];
        }
    }
    
    while (opStack.count > 0) {
        [output addObject:[opStack lastObject]];
        [opStack removeLastObject];
    }
    
    return output;
}

- (CGFloat)evaluateRPN:(NSArray *)rpn {
    NSMutableArray *stack = [NSMutableArray array];
    
    for (NSString *tok in rpn) {
        if ([tok isEqualToString:@"+"] || [tok isEqualToString:@"-"] || [tok isEqualToString:@"*"] || [tok isEqualToString:@"/"] || [tok isEqualToString:@"%"]) {
            if (stack.count < 2) {
                if (stack.count == 1 && [tok isEqualToString:@"-"]) {
                    CGFloat a = [[stack lastObject] doubleValue];
                    [stack removeLastObject];
                    [stack addObject:@(-a)];
                }
                continue;
            }
            CGFloat b = [[stack lastObject] doubleValue];
            [stack removeLastObject];
            CGFloat a = [[stack lastObject] doubleValue];
            [stack removeLastObject];
            
            CGFloat res = 0.0;
            if ([tok isEqualToString:@"+"]) res = a + b;
            else if ([tok isEqualToString:@"-"]) res = a - b;
            else if ([tok isEqualToString:@"*"]) res = a * b;
            else if ([tok isEqualToString:@"/"]) res = (b != 0.0) ? a / b : 0.0;
            else if ([tok isEqualToString:@"%"]) res = (b != 0.0) ? fmod(a, b) : 0.0;
            
            [stack addObject:@(res)];
        } else if ([self isFunction:tok]) {
            NSString *fn = [tok lowercaseString];
            if ([fn isEqualToString:@"sin"] && stack.count >= 1) {
                CGFloat a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(sin(a))];
            } else if ([fn isEqualToString:@"cos"] && stack.count >= 1) {
                CGFloat a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(cos(a))];
            } else if ([fn isEqualToString:@"tan"] && stack.count >= 1) {
                CGFloat a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(tan(a))];
            } else if ([fn isEqualToString:@"sqrt"] && stack.count >= 1) {
                CGFloat a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(sqrt(MAX(0.0, a)))];
            } else if ([fn isEqualToString:@"abs"] && stack.count >= 1) {
                CGFloat a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(fabs(a))];
            } else if ([fn isEqualToString:@"min"] && stack.count >= 2) {
                CGFloat b = [[stack lastObject] doubleValue]; [stack removeLastObject];
                CGFloat a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(MIN(a, b))];
            } else if ([fn isEqualToString:@"max"] && stack.count >= 2) {
                CGFloat b = [[stack lastObject] doubleValue]; [stack removeLastObject];
                CGFloat a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(MAX(a, b))];
            } else if ([fn isEqualToString:@"rand"] && stack.count >= 1) {
                CGFloat a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@((arc4random() % 1000) / 1000.0 * a)];
            }
        } else {
            // Либо число, либо переменная
            NSScanner *scanner = [NSScanner scannerWithString:tok];
            double val = 0.0;
            if ([scanner scanDouble:&val] && [scanner isAtEnd]) {
                [stack addObject:@(val)];
            } else {
                CGFloat varVal = [self getVariable:tok];
                [stack addObject:@(varVal)];
            }
        }
    }
    
    return stack.count > 0 ? [[stack lastObject] doubleValue] : 0.0;
}

@end
