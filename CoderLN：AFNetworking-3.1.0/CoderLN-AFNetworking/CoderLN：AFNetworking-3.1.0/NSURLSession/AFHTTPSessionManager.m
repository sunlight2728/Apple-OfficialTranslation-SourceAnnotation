// AFHTTPSessionManager.m
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//（https://dwz.cn/rC1LGk2f）

#import "AFHTTPSessionManager.h"

#import "AFURLRequestSerialization.h"
#import "AFURLResponseSerialization.h"

#import <Availability.h>
#import <TargetConditionals.h>
#import <Security/Security.h>

#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#elif TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif

@interface AFHTTPSessionManager ()
/**
 注意：与头文件中暴露给外部的 baseUrl 属性不同的，该属性前缀是 **readwrite**
 */
@property (readwrite, nonatomic, strong) NSURL *baseURL;
@end

@implementation AFHTTPSessionManager
@dynamic responseSerializer;

+ (instancetype)manager {
    return [[[self class] alloc] initWithBaseURL:nil];
}

- (instancetype)init {
    return [self initWithBaseURL:nil];
}

- (instancetype)initWithBaseURL:(NSURL *)url {
    return [self initWithBaseURL:url sessionConfiguration:nil];
}

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration {
    return [self initWithBaseURL:nil sessionConfiguration:configuration];
}

/*
 全能初始化方法：在其中通过configuration生成了AFHTTPSessionManager的实例对象，
 并初始化了 baseURL,requestSerializer,responseSerializer 属性
 注意：session manager的对象是调用父类 AFURLSessionManager 的 initWithSessionConfiguration: 方法生成的，
 所以要研究下父类AFURLSessionManager
 */
- (instancetype)initWithBaseURL:(NSURL *)url
           sessionConfiguration:(NSURLSessionConfiguration *)configuration
{
    self = [super initWithSessionConfiguration:configuration];
    if (!self) {
        return nil;
    }
    /**
     absoluteString 属性可以将NSUR转换为NSString；
     而下面两个方法却是NSURL的初始化方法，将NSString转换为NSURL了。
     这几个方法涉及到NSURL和NSString的互相转换。
     */
    // Ensure terminal slash for baseURL path, so that NSURL +URLWithString:relativeToURL: works as expected
    if ([[url path] length] > 0 && ![[url absoluteString] hasSuffix:@"/"]) {
        url = [url URLByAppendingPathComponent:@""];
    }
   
    self.baseURL = url;

    /*
     请求序列化器和响应序列化器进行初始化。
     请求序列化器是 AFHTTPRequestSerializer 类型，
     响应序列化器是 AFJSONResponseSerializer 类型
     */
    self.requestSerializer = [AFHTTPRequestSerializer serializer];
    self.responseSerializer = [AFJSONResponseSerializer serializer];

    return self;
}


/**
 疑问：
 为什么同是属性的setter方法，一个是直接将其值赋给变量，
 而另一个要调用父类的setter方法呢，父类的setter方法也同样是将其值赋给变量 ？
 */
- (void)setRequestSerializer:(AFHTTPRequestSerializer <AFURLRequestSerialization> *)requestSerializer {
    NSParameterAssert(requestSerializer);

    _requestSerializer = requestSerializer;
}

- (void)setResponseSerializer:(AFHTTPResponseSerializer <AFURLResponseSerialization> *)responseSerializer {
    NSParameterAssert(responseSerializer);

    [super setResponseSerializer:responseSerializer];
}

#pragma mark -

- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                      success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{

    return [self GET:URLString parameters:parameters progress:nil success:success failure:failure];
}


#pragma mark - 调用GET请求的入口方法 ⦁
- (NSURLSessionDataTask *)GET:(NSString *)URLString
                   parameters:(id)parameters
                     progress:(void (^)(NSProgress * _Nonnull))downloadProgress
                      success:(void (^)(NSURLSessionDataTask * _Nonnull, id _Nullable))success
                      failure:(void (^)(NSURLSessionDataTask * _Nullable, NSError * _Nonnull))failure
{

    //方法内部调用其它方法生成NSURLSessionDataTask的实例对象
    NSURLSessionDataTask *dataTask = [self dataTaskWithHTTPMethod:@"GET"
                                                        URLString:URLString
                                                       parameters:parameters
                                                   uploadProgress:nil
                                                 downloadProgress:downloadProgress
                                                          success:success
                                                          failure:failure];

    //然后dataTask再调用resume启动请求任务
    [dataTask resume];

    return dataTask;
}

- (NSURLSessionDataTask *)HEAD:(NSString *)URLString
                    parameters:(id)parameters
                       success:(void (^)(NSURLSessionDataTask *task))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    NSURLSessionDataTask *dataTask = [self dataTaskWithHTTPMethod:@"HEAD" URLString:URLString parameters:parameters uploadProgress:nil downloadProgress:nil success:^(NSURLSessionDataTask *task, __unused id responseObject) {
        if (success) {
            success(task);
        }
    } failure:failure];

    [dataTask resume];

    return dataTask;
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    return [self POST:URLString parameters:parameters progress:nil success:success failure:failure];
}


#pragma mark - 调用POST请求的入口方法 ⦁
- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
                      progress:(void (^)(NSProgress * _Nonnull))uploadProgress
                       success:(void (^)(NSURLSessionDataTask * _Nonnull, id _Nullable))success
                       failure:(void (^)(NSURLSessionDataTask * _Nullable, NSError * _Nonnull))failure
{
    //方法内部调用其它方法生成NSURLSessionDataTask的实例对象
    NSURLSessionDataTask *dataTask = [self dataTaskWithHTTPMethod:@"POST" URLString:URLString parameters:parameters uploadProgress:uploadProgress downloadProgress:nil success:success failure:failure];

    //然后dataTask再调用resume启动请求任务
    [dataTask resume];

    return dataTask;
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(nullable id)parameters
     constructingBodyWithBlock:(nullable void (^)(id<AFMultipartFormData> _Nonnull))block
                       success:(nullable void (^)(NSURLSessionDataTask * _Nonnull, id _Nullable))success
                       failure:(nullable void (^)(NSURLSessionDataTask * _Nullable, NSError * _Nonnull))failure
{
    return [self POST:URLString parameters:parameters constructingBodyWithBlock:block progress:nil success:success failure:failure];
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
     constructingBodyWithBlock:(void (^)(id <AFMultipartFormData> formData))block
                      progress:(nullable void (^)(NSProgress * _Nonnull))uploadProgress
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    NSError *serializationError = nil;
    NSMutableURLRequest *request = [self.requestSerializer multipartFormRequestWithMethod:@"POST" URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString] parameters:parameters constructingBodyWithBlock:block error:&serializationError];
    if (serializationError) {
        if (failure) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
            dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                failure(nil, serializationError);
            });
#pragma clang diagnostic pop
        }

        return nil;
    }

    __block NSURLSessionDataTask *task = [self uploadTaskWithStreamedRequest:request progress:uploadProgress completionHandler:^(NSURLResponse * __unused response, id responseObject, NSError *error) {
        if (error) {
            if (failure) {
                failure(task, error);
            }
        } else {
            if (success) {
                success(task, responseObject);
            }
        }
    }];

    [task resume];

    return task;
}

- (NSURLSessionDataTask *)PUT:(NSString *)URLString
                   parameters:(id)parameters
                      success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    NSURLSessionDataTask *dataTask = [self dataTaskWithHTTPMethod:@"PUT" URLString:URLString parameters:parameters uploadProgress:nil downloadProgress:nil success:success failure:failure];

    [dataTask resume];

    return dataTask;
}

- (NSURLSessionDataTask *)PATCH:(NSString *)URLString
                     parameters:(id)parameters
                        success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                        failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    NSURLSessionDataTask *dataTask = [self dataTaskWithHTTPMethod:@"PATCH" URLString:URLString parameters:parameters uploadProgress:nil downloadProgress:nil success:success failure:failure];

    [dataTask resume];

    return dataTask;
}

- (NSURLSessionDataTask *)DELETE:(NSString *)URLString
                      parameters:(id)parameters
                         success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                         failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    NSURLSessionDataTask *dataTask = [self dataTaskWithHTTPMethod:@"DELETE" URLString:URLString parameters:parameters uploadProgress:nil downloadProgress:nil success:success failure:failure];

    [dataTask resume];

    return dataTask;
}


#pragma mark - dataTaskWithHTTPMethod: ⦁[GET|POST]
/**
 内部会调用到dataTaskWithHTTPMethod:方法中，创建NSURLSessionDataTask的实例对象并返回这个实例。可以选择性地传入各类Block回调，用于监听网络请求的进度，比如上传进度，下载进度，请求成功，请求失败。
 */
- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                                  uploadProgress:(nullable void (^)(NSProgress *uploadProgress)) uploadProgress
                                downloadProgress:(nullable void (^)(NSProgress *downloadProgress)) downloadProgress
                                         success:(void (^)(NSURLSessionDataTask *, id))success
                                         failure:(void (^)(NSURLSessionDataTask *, NSError *))failure
{
    NSError *serializationError = nil;
    //首先调用请求序列化的requestWithMethod:方法生成请求mutableRequest。若生成mutableRequest时出现错误，则回调该错误。
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString] parameters:parameters error:&serializationError];
    if (serializationError) {
        if (failure) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
            dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                failure(nil, serializationError);
            });
#pragma clang diagnostic pop
        }

        return nil;
    }

    //将上面生成的mutableRequest作为参数传入dataTaskWithRequest方法，生成dataTask实例对象
    __block NSURLSessionDataTask *dataTask = nil;
    dataTask = [self dataTaskWithRequest:request
                          uploadProgress:uploadProgress
                        downloadProgress:downloadProgress
                       completionHandler:^(NSURLResponse * __unused response, id responseObject, NSError *error) {
        if (error) {
            if (failure) {
                failure(dataTask, error);
            }
        } else {
            if (success) {
                success(dataTask, responseObject);
            }
        }
    }];

    return dataTask;
}

#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, baseURL: %@, session: %@, operationQueue: %@>", NSStringFromClass([self class]), self, [self.baseURL absoluteString], self.session, self.operationQueue];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    NSURL *baseURL = [decoder decodeObjectOfClass:[NSURL class] forKey:NSStringFromSelector(@selector(baseURL))];
    NSURLSessionConfiguration *configuration = [decoder decodeObjectOfClass:[NSURLSessionConfiguration class] forKey:@"sessionConfiguration"];
    if (!configuration) {
        NSString *configurationIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        if (configurationIdentifier) {
#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 80000) || (defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1100)
            configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:configurationIdentifier];
#else
            configuration = [NSURLSessionConfiguration backgroundSessionConfiguration:configurationIdentifier];
#endif
        }
    }

    self = [self initWithBaseURL:baseURL sessionConfiguration:configuration];
    if (!self) {
        return nil;
    }

    self.requestSerializer = [decoder decodeObjectOfClass:[AFHTTPRequestSerializer class] forKey:NSStringFromSelector(@selector(requestSerializer))];
    self.responseSerializer = [decoder decodeObjectOfClass:[AFHTTPResponseSerializer class] forKey:NSStringFromSelector(@selector(responseSerializer))];
    AFSecurityPolicy *decodedPolicy = [decoder decodeObjectOfClass:[AFSecurityPolicy class] forKey:NSStringFromSelector(@selector(securityPolicy))];
    if (decodedPolicy) {
        self.securityPolicy = decodedPolicy;
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    [coder encodeObject:self.baseURL forKey:NSStringFromSelector(@selector(baseURL))];
    if ([self.session.configuration conformsToProtocol:@protocol(NSCoding)]) {
        [coder encodeObject:self.session.configuration forKey:@"sessionConfiguration"];
    } else {
        [coder encodeObject:self.session.configuration.identifier forKey:@"identifier"];
    }
    [coder encodeObject:self.requestSerializer forKey:NSStringFromSelector(@selector(requestSerializer))];
    [coder encodeObject:self.responseSerializer forKey:NSStringFromSelector(@selector(responseSerializer))];
    [coder encodeObject:self.securityPolicy forKey:NSStringFromSelector(@selector(securityPolicy))];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    AFHTTPSessionManager *HTTPClient = [[[self class] allocWithZone:zone] initWithBaseURL:self.baseURL sessionConfiguration:self.session.configuration];

    HTTPClient.requestSerializer = [self.requestSerializer copyWithZone:zone];
    HTTPClient.responseSerializer = [self.responseSerializer copyWithZone:zone];
    HTTPClient.securityPolicy = [self.securityPolicy copyWithZone:zone];
    return HTTPClient;
}

@end
