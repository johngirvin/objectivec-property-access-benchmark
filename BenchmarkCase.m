#import "BenchmarkCase.h"

@implementation BenchmarkCase

+ (BenchmarkCase *) caseWithName:(NSString *)name andSelector:(SEL)selector
{
    return [[self alloc] initWithName:name andSelector:selector];
}

- initWithName:(NSString *)name andSelector:(SEL)selector
{
    if ((self = [super init]))
    {
        _name     = name;
        _selector = selector;
    }
    return self;
}

@end
