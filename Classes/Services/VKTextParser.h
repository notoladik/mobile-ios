#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface VKTextMention : NSObject
@property (nonatomic, copy) NSString *targetId; // e.g. "id13" or "club145"
@property (nonatomic, copy) NSString *name;     // e.g. "Ayato"
@property (nonatomic, assign) NSRange range;    // Range in cleaned text
@end

@interface VKTextParser : NSObject

/**
 * Strips raw VK mention markup from text, leaving only the readable name:
 * "[id13|Ayato]" -> "Ayato"
 * "@id13 (Ayato)" -> "Ayato"
 * "*club123 (Group)" -> "Group"
 */
+ (NSString *)cleanTextForDisplay:(NSString *)rawText;

/**
 * Parses raw text and returns an NSAttributedString where mentions are styled with linkColor.
 */
+ (NSAttributedString *)attributedStringForText:(NSString *)rawText
                                           font:(UIFont *)font
                                      textColor:(UIColor *)textColor
                                      linkColor:(UIColor *)linkColor;

/**
 * Returns a list of VKTextMention objects found in the raw text with their ranges in the cleaned string.
 */
+ (NSArray<VKTextMention *> *)mentionsInText:(NSString *)rawText;

@end
