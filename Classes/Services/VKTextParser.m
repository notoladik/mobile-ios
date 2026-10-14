#import "VKTextParser.h"

@implementation VKTextMention
@end

@implementation VKTextParser

+ (NSString *)cleanTextForDisplay:(NSString *)rawText {
    if (!rawText || rawText.length == 0) return @"";
    
    // 1. [id123|Name] or [club123|Name] or [alias|Name]
    NSRegularExpression *bracketRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[([a-zA-Z0-9_]+)\\|([^\\]]+)\\]"
                                                                                  options:0
                                                                                    error:nil];
    NSString *cleaned = [bracketRegex stringByReplacingMatchesInString:rawText
                                                               options:0
                                                                 range:NSMakeRange(0, rawText.length)
                                                          withTemplate:@"$2"];
    
    // 2. @id123 (Name) or *id123 (Name)
    NSRegularExpression *atRegex = [NSRegularExpression regularExpressionWithPattern:@"[@\\*]([a-zA-Z0-9_]+)\\s*\\(([^)]+)\\)"
                                                                             options:0
                                                                               error:nil];
    cleaned = [atRegex stringByReplacingMatchesInString:cleaned
                                                options:0
                                                  range:NSMakeRange(0, cleaned.length)
                                           withTemplate:@"$2"];
    
    return cleaned;
}

+ (NSArray<VKTextMention *> *)mentionsInText:(NSString *)rawText {
    if (!rawText || rawText.length == 0) return @[];
    
    NSMutableArray<VKTextMention *> *mentions = [NSMutableArray array];
    
    // Regex for [target|name]
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[([a-zA-Z0-9_]+)\\|([^\\]]+)\\]"
                                                                           options:0
                                                                             error:nil];
    
    // We walk through the string and build the cleaned version while tracking mention ranges
    NSMutableString *cleaned = [NSMutableString string];
    NSUInteger lastIdx = 0;
    
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:rawText options:0 range:NSMakeRange(0, rawText.length)];
    for (NSTextCheckingResult *match in matches) {
        if (match.numberOfRanges >= 3) {
            NSRange fullRange = match.range;
            NSRange targetRange = [match rangeAtIndex:1];
            NSRange nameRange = [match rangeAtIndex:2];
            
            // Append preceding text
            if (fullRange.location > lastIdx) {
                NSString *pre = [rawText substringWithRange:NSMakeRange(lastIdx, fullRange.location - lastIdx)];
                [cleaned appendString:pre];
            }
            
            NSString *target = [rawText substringWithRange:targetRange];
            NSString *name = [rawText substringWithRange:nameRange];
            
            VKTextMention *m = [[VKTextMention alloc] init];
            m.targetId = target;
            m.name = name;
            m.range = NSMakeRange(cleaned.length, name.length);
            [mentions addObject:m];
            
            [cleaned appendString:name];
            lastIdx = fullRange.location + fullRange.length;
        }
    }
    
    if (lastIdx < rawText.length) {
        [cleaned appendString:[rawText substringFromIndex:lastIdx]];
    }
    
    // Also parse alternate format @target (name)
    NSRegularExpression *atRegex = [NSRegularExpression regularExpressionWithPattern:@"[@\\*]([a-zA-Z0-9_]+)\\s*\\(([^)]+)\\)"
                                                                             options:0
                                                                               error:nil];
    // If there were @mentions, we can check cleaned
    NSString *currentCleaned = [cleaned copy];
    NSArray<NSTextCheckingResult *> *atMatches = [atRegex matchesInString:currentCleaned options:0 range:NSMakeRange(0, currentCleaned.length)];
    if (atMatches.count > 0) {
        // Simple fallback
        for (NSTextCheckingResult *match in atMatches) {
            if (match.numberOfRanges >= 3) {
                NSString *target = [currentCleaned substringWithRange:[match rangeAtIndex:1]];
                NSString *name = [currentCleaned substringWithRange:[match rangeAtIndex:2]];
                VKTextMention *m = [[VKTextMention alloc] init];
                m.targetId = target;
                m.name = name;
                m.range = match.range;
                [mentions addObject:m];
            }
        }
    }
    
    return mentions;
}

+ (NSAttributedString *)attributedStringForText:(NSString *)rawText
                                           font:(UIFont *)font
                                      textColor:(UIColor *)textColor
                                      linkColor:(UIColor *)linkColor {
    if (!rawText || rawText.length == 0) return [[NSAttributedString alloc] initWithString:@""];
    if (!font) font = [UIFont systemFontOfSize:15];
    if (!textColor) textColor = [UIColor blackColor];
    if (!linkColor) linkColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    
    NSString *clean = [self cleanTextForDisplay:rawText];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:clean
                                                                             attributes:@{
                                                                                 NSFontAttributeName: font,
                                                                                 NSForegroundColorAttributeName: textColor
                                                                             }];
    
    NSArray<VKTextMention *> *mentions = [self mentionsInText:rawText];
    for (VKTextMention *m in mentions) {
        if (m.range.location != NSNotFound && (m.range.location + m.range.length) <= attr.length) {
            [attr addAttributes:@{
                NSForegroundColorAttributeName: linkColor,
                NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)
            } range:m.range];
        }
    }
    
    return attr;
}

@end
