#include "VTPG_Common.h"

#ifdef DEBUG

	#define DLog(...) NSLog(@"%s %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])
	#define ALog(...) [[NSAssertionHandler currentHandler] handleFailureInFunction:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding] file:[NSString stringWithCString:__FILE__ encoding:NSUTF8StringEncoding] lineNumber:__LINE__ description:__VA_ARGS__]
	#define LLog(format,...) {NSString *file = [[NSString stringWithUTF8String:__FILE__] lastPathComponent]; printf("%s- %s:%d - ", __PRETTY_FUNCTION__, [file UTF8String], __LINE__ ); quietLog((format),##__VA_ARGS__); }

#else
	
	#define DLog(...) do { } while (0)
	#define LLog(format, ...) do {} while (0)
	#ifndef NS_BLOCK_ASSERTIONS
		#define NS_BLOCK_ASSERTIONS
	#endif
	#define ALog(...) NSLog(@"%s %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])
#endif

#define ZAssert(condition, ...) do { if (!(condition)) { ALog(__VA_ARGS__); }} while(0)

void quietLog(NSString* format, ...);