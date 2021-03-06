//
//  PSTCKAPIPostRequest.m
//  Paystack
//

#import "PSTCKAPIPostRequest.h"
#import "PSTCKAPIClient.h"
#import "PSTCKAPIClient+Private.h"
#import "PaystackError.h"

@implementation PSTCKAPIPostRequest

+ (void)startWithAPIClient:(PSTCKAPIClient *)apiClient
                  endpoint:(NSString *)endpoint
                  postData:(NSData *)postData
                serializer:(id<PSTCKAPIResponseDecodable>)serializer
                completion:(void (^)(id<PSTCKAPIResponseDecodable>, NSError *))completion {
    
    NSURL *url = [apiClient.apiURL URLByAppendingPathComponent:endpoint];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = postData;
//    NSLog(@"%@",postData);
    
    [[apiClient.urlSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable body, __unused NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSDictionary *jsonDictionary = body ? [NSJSONSerialization JSONObjectWithData:body options:0 error:NULL] : nil;
        NSString *bodyString = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];

        id<PSTCKAPIResponseDecodable> responseObject = [[serializer class] decodedObjectFromAPIResponse:jsonDictionary];
        NSError *returnedError = [NSError pstck_errorFromPaystackResponse:jsonDictionary] ?: error;
        if (!responseObject && !returnedError) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: PSTCKUnexpectedError,
                                       PSTCKErrorMessageKey: [@"The response from Paystack failed to get parsed into valid JSON. Response was: " stringByAppendingString:bodyString]
                                       };
            returnedError = [[NSError alloc] initWithDomain:PaystackDomain code:PSTCKAPIError userInfo:userInfo];
        }
        // We're using the api client's operation queue instead of relying on the url session's operation queue
        // because the api client's queue is mutable and may have changed after initialization (not ideal)
        if (returnedError) {
            [apiClient.operationQueue addOperationWithBlock:^{
                completion(nil, returnedError);
            }];
            return;
        }
        [apiClient.operationQueue addOperationWithBlock:^{
            completion(responseObject, nil);
        }];
    }] resume];
    
}

@end
