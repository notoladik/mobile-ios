#import "VKAPIClient.h"
#import "VKAppConfig.h"
#import "VKAuthService.h"
#import "VKCrashLogger.h"

static NSString *VKPercentEscapedString(NSString *string) {
    if (!string) return @"";
    static NSString *const kGeneralDelimitersToEncode = @":/?#[]@";
    static NSString *const kSubDelimitersToEncode = @"!$&'()*+,;=";
    
    NSMutableString *cleanString = [NSMutableString stringWithString:string];
    CFStringRef escaped = CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault,
        (__bridge CFStringRef)cleanString,
        NULL,
        (__bridge CFStringRef)[kGeneralDelimitersToEncode stringByAppendingString:kSubDelimitersToEncode],
        kCFStringEncodingUTF8
    );
    return (__bridge_transfer NSString *)escaped ?: string;
}

@implementation VKAPIClient

+ (instancetype)sharedClient {
    static VKAPIClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[self alloc] init];
    });
    return _sharedClient;
}

- (void)callMethod:(NSString *)method
        parameters:(NSDictionary *)parameters
 completionHandler:(VKAPICompletionBlock)completionHandler {
    
    NSMutableDictionary *params = parameters ? [parameters mutableCopy] : [NSMutableDictionary dictionary];
    params[@"v"] = @"5.131";
    
    NSString *token = [[VKAuthService sharedService] accessToken];
    if (token.length > 0) {
        params[@"access_token"] = token;
    }
    
    NSMutableArray *bodyParts = [NSMutableArray array];
    for (NSString *key in params) {
        NSString *val = [NSString stringWithFormat:@"%@", params[key]];
        NSString *encodedKey = VKPercentEscapedString(key);
        NSString *encodedVal = VKPercentEscapedString(val);
        [bodyParts addObject:[NSString stringWithFormat:@"%@=%@", encodedKey, encodedVal]];
    }
    
    NSString *bodyString = [bodyParts componentsJoinedByString:@"&"];
    NSData *bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *baseURL = [VKAppConfig apiBaseURL];
    NSString *urlString = [NSString stringWithFormat:@"%@method/%@", [baseURL absoluteString], method];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"okhttp/4.12.0" forHTTPHeaderField:@"User-Agent"];
    [request setHTTPBody:bodyData];
    
    [self executeRequest:request completionHandler:completionHandler];
}

- (void)requestTokenWithUsername:(NSString *)username
                         password:(NSString *)password
                             code:(NSString *)code
                completionHandler:(VKAPICompletionBlock)completionHandler {
    
    NSURL *baseURL = [VKAppConfig apiBaseURL];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@token", [baseURL absoluteString]]];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"username": username ?: @"",
        @"password": password ?: @"",
        @"grant_type": @"password",
        @"client_name": @"openvk_ios"
    }];
    if (code && code.length > 0) {
        params[@"code"] = code;
    }
    
    NSMutableArray *bodyParts = [NSMutableArray array];
    for (NSString *key in params) {
        NSString *val = [NSString stringWithFormat:@"%@", params[key]];
        NSString *encodedKey = VKPercentEscapedString(key);
        NSString *encodedVal = VKPercentEscapedString(val);
        [bodyParts addObject:[NSString stringWithFormat:@"%@=%@", encodedKey, encodedVal]];
    }
    
    NSString *bodyString = [bodyParts componentsJoinedByString:@"&"];
    NSData *bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"okhttp/4.12.0" forHTTPHeaderField:@"User-Agent"];
    [request setHTTPBody:bodyData];
    
    [self executeRequest:request completionHandler:completionHandler];
}

- (void)executeRequest:(NSURLRequest *)request completionHandler:(VKAPICompletionBlock)completionHandler {
    if (NSClassFromString(@"NSURLSession")) {
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handleResponseData:data response:response error:error completionHandler:completionHandler];
        }];
        [task resume];
    } else {
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            [self handleResponseData:data response:response error:error completionHandler:completionHandler];
        }];
    }
}

- (void)handleResponseData:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error completionHandler:(VKAPICompletionBlock)completionHandler {
    if (error) {
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, error);
            });
        }
        return;
    }
    
    if (!data || data.length == 0) {
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, nil);
            });
        }
        return;
    }
    
    NSError *jsonError = nil;
    id jsonObj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (jsonError) {
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, jsonError);
            });
        }
        return;
    }
    
    if (completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(jsonObj, nil);
        });
    }
}

@end
