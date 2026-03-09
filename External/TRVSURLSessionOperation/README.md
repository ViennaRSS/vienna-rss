# TRVSURLSessionOperation

By [@travisjeffery](http://twitter.com/travisjeffery).

## NSURLSession and NSOperationQueue working together

`TRVSURLSessionOperation` is an `NSOperation` subclass that wraps `NSURLSessionTask` so you can use them in a `NSOperationQueue`.

With this you can:

- Schedule network requests (i.e. run request A then request B, and give requests priority)
- Limit the number of concurrent network requests (e.g. have 5 network requests running at any given time)
- Control these network operations the same as other `NSOperation` objects (e.g. you have an `NSOperation` that creates an image, then an `TRVSURLSessionOperation` that uploads that image to a web service)

## Usage

``` objective-c
NSOperationQueue *queue = [[NSOperationQueue alloc] init];
NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

[queue addOperation:[[TRVSURLSessionOperation alloc] initWithSession:session request:[NSURLRequest requestWithURL:@"https://twitter.com/travisjeffery"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { ... }]];
```

### Run a request on the completion of another, specific request

For example, you have an initial request to log a user in or fetch their settings, and you want subsequent requests to wait for that initial request to finish and then they run.

``` objective-c
NSOperationQueue *queue = [[NSOperationQueue alloc] init];
NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

TRVSURLSessionOperation *settingsOperation = [[TRVSURLSessionOperation alloc] initWithSession:session request:[NSURLRequest requestWithURL:@"..."] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { ... }];

TRVSURLSessionOperation *anotherOperation = [[TRVSURLSessionOperation alloc] initWithSession:session request:[NSURLRequest requestWithURL:@"..."] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { ... }];

// get some settings for your app from your server, and queue subsequent requests that depend on those settings.
[anotherOperation addDependency:settingsOperation];

[queue addOperations:@[ loginOperation, settingsOperation ] waitUntilAllOperationsAreFinished:NO];
```

### Pause and resume/suspend requests from executing

``` objective-c
NSOperationQueue *queue = [[NSOperation alloc] init];
queue.suspended = YES;

// these request/operations won't run
[queue addOperation:[[TRVSURLSessionOperation alloc] initWithSession:session request:[NSURLRequest requestWithURL:@"https://twitter.com/travisjeffery"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { ... }]];

[queue addOperation:[[TRVSURLSessionOperation alloc] initWithSession:session request:[NSURLRequest requestWithURL:@"https://github.com/travisjeffery"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { ... }]];

queue.suspended = NO;
// until now
```

### Limit the number of concurrent requests

``` objective-c
NSOperationQueue *queue = [[NSOperationQueue alloc] init];
queue.maxConcurrentOperationCount = 1; // only one request will run at once

NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

[queue addOperation:[[TRVSURLSessionOperation alloc] initWithSession:session request:[NSURLRequest requestWithURL:@"https://twitter.com/travisjeffery"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { ... }]];

[queue addOperation:[[TRVSURLSessionOperation alloc] initWithSession:session request:[NSURLRequest requestWithURL:@"https://github.com/travisjeffery"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { ... }]];
```

### Wait until all requests are finished


``` objective-c
NSOperationQueue *queue = [[NSOperationQueue alloc] init];

NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

[queue addOperation:[[TRVSURLSessionOperation alloc] initWithSession:session request:[NSURLRequest requestWithURL:@"https://twitter.com/travisjeffery"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { ... }]];

[queue addOperation:[[TRVSURLSessionOperation alloc] initWithSession:session request:[NSURLRequest requestWithURL:@"https://github.com/travisjeffery"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { ... }]];

[queue waitUntilAllOperationsAreFinished];

NSLog(@"All requests are done!");
```

## Install

Use CocoaPods, and put the following in your Podfile:

``` ruby
pod 'TRVSURLSessionOperation', '~> 0.0.1'
```

Or manually drag the TRVSURLSessionOperation folder into your Xcode project.
