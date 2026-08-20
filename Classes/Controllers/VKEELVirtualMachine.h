#import <Foundation/Foundation.h>

// Виртуальная машина и интерпретатор языка формул EEL (Expression Evaluation Language)
@interface VKEELVirtualMachine : NSObject

// Контекст переменных (time, bass, mid, treb, frame, zoom, rot, warp, dx, dy, cx, cy, rad, ang, q1..q8 и др.)
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *variables;

- (void)setVariable:(NSString *)name value:(CGFloat)value;
- (CGFloat)getVariable:(NSString *)name;

// Компиляция и исполнение строкового выражения EEL (например: "rot = rot + 0.02 * sin(time * 2.0); zoom = 0.98 - 0.04 * bass;")
- (void)evaluateScript:(NSString *)script;

// Быстрое вычисление одиночного выражения (например: "sin(ang * 4.0 + time) * 0.1")
- (CGFloat)evaluateExpression:(NSString *)expr;

@end
