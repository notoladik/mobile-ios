#import <Foundation/Foundation.h>

typedef void (^VKAPICompletionBlock)(id response, NSError *error);

@interface VKAPIClient : NSObject

+ (instancetype)sharedClient;

- (void)callMethod:(NSString *)method
        parameters:(NSDictionary *)parameters
 completionHandler:(VKAPICompletionBlock)completionHandler;

- (void)requestTokenWithUsername:(NSString *)username
                        password:(NSString *)password
                            code:(NSString *)code
               completionHandler:(VKAPICompletionBlock)completionHandler;

- (void)uploadFileWithURL:(NSString *)uploadURL
                fieldName:(NSString *)fieldName
                 fileName:(NSString *)fileName
                 mimeType:(NSString *)mimeType
                 fileData:(NSData *)fileData
        completionHandler:(VKAPICompletionBlock)completionHandler;

@end
