// Adapted from
// https://mikeash.com/pyblog/performance-comparisons-of-common-operations-iphone-edition.html

#import "Benchmark.h"
#import "BenchmarkCase.h"
#import <mach/mach_time.h>
#import <pthread.h>

// ----------------------------------------------------------------------------------------------
// TYPES
struct Result
{
    int     iterations;
    double  totalDuration;
    double  singleIterationNanosec;
};

// ----------------------------------------------------------------------------------------------
// Benchmark IMPLEMENTATION

@interface Benchmark ()
@property (nonatomic) int testDirect;
@property (nonatomic) int testNonAtomic;
@property (atomic)    int testAtomic;
@end

@implementation Benchmark
{
    int      mIterations;
    uint64_t mStartTime;
    uint64_t mEndTime;
}

// ----------------------------------------------------------------------------------------------

- (void) test
{
    // test cases to run
    NSArray *testCases = @[
        [BenchmarkCase caseWithName:@"Set property (direct)" andSelector:@selector(testSetPropertyDirect)],
        [BenchmarkCase caseWithName:@"Update property (direct)" andSelector:@selector(testUpdatePropertyDirect)],
        [BenchmarkCase caseWithName:@"Set property (nonatomic)" andSelector:@selector(testSetPropertyNonAtomic)],
        [BenchmarkCase caseWithName:@"Update property (nonatomic)" andSelector:@selector(testUpdatePropertyNonAtomic)],
        [BenchmarkCase caseWithName:@"Set property (atomic)" andSelector:@selector(testSetPropertyAtomic)],
        [BenchmarkCase caseWithName:@"Update property (atomic)" andSelector:@selector(testUpdatePropertyAtomic)],
        [BenchmarkCase caseWithName:@"C++ virtual method call" andSelector:@selector(testCPPVirtualCall)],
        [BenchmarkCase caseWithName:@"Objective-C message send" andSelector:@selector(testMessaging)],
        [BenchmarkCase caseWithName:@"IMP-cached message send" andSelector:@selector(testIMPCachedMessaging)],
        [BenchmarkCase caseWithName:@"NSInvocation message send" andSelector:@selector(testNSInvocation)],
        [BenchmarkCase caseWithName:@"Integer division" andSelector:@selector(testIntDivision)],
        [BenchmarkCase caseWithName:@"Floating-point division" andSelector:@selector(testFloatDivision)],
        [BenchmarkCase caseWithName:@"Float division with int conversion" andSelector:@selector(testFloatConversionDivision)],
        [BenchmarkCase caseWithName:@"NSObject alloc/init/release" andSelector:@selector(testObjectCreation)],
        [BenchmarkCase caseWithName:@"NSAutoreleasePool alloc/init/release" andSelector:@selector(testPoolCreation)],
        [BenchmarkCase caseWithName:@"16 byte malloc/free" andSelector:@selector(testSmallMallocFree)],
        [BenchmarkCase caseWithName:@"16MB malloc/free" andSelector:@selector(testLargeMallocFree)],
        [BenchmarkCase caseWithName:@"16 byte memcpy" andSelector:@selector(testSmallMemcpy)],
        [BenchmarkCase caseWithName:@"1MB memcpy" andSelector:@selector(testLargeMemcpy)],
        [BenchmarkCase caseWithName:@"Write 16-byte file" andSelector:@selector(testWriteSmallFile)],
        [BenchmarkCase caseWithName:@"Write 16-byte file (atomic)" andSelector:@selector(testWriteSmallFileAtomic)],
        [BenchmarkCase caseWithName:@"Write 16MB file" andSelector:@selector(testWriteLargeFile)],
        [BenchmarkCase caseWithName:@"Write 16MB file (atomic)" andSelector:@selector(testWriteLargeFileAtomic)],
        [BenchmarkCase caseWithName:@"Read 16-byte file" andSelector:@selector(testReadSmallFile)],
        [BenchmarkCase caseWithName:@"Read 16MB file" andSelector:@selector(testReadLargeFile)],
        [BenchmarkCase caseWithName:@"pthread create/join" andSelector:@selector(testSpawnThread)],
        [BenchmarkCase caseWithName:@"Zero-second delayed perform" andSelector:@selector(testDelayedPerform)]
    ];

    // warm up
    mIterations = 1000000000;
    [self timeForSelector:@selector(testNothing)];

    // run test cases and gather results
    NSMutableArray *testResults = [NSMutableArray array];
    for (BenchmarkCase *testCase in testCases)
    {
        struct Result result = [self timeForSelector:testCase.selector];
        struct Result overheadResult = [self timeForSelector:@selector( testNothing )];

        double total = result.totalDuration - overheadResult.totalDuration;
        double each = result.singleIterationNanosec - overheadResult.singleIterationNanosec;

        NSLog(@"%-40s| i:%11d t:%5.1fs e:%12.1fns", [testCase.name UTF8String], result.iterations, total, each);

        [testResults addObject:@{
                @"name" : testCase.name,
                @"iterations" : @(result.iterations),
                @"total" : @(total),
                @"each" : @(each)
        }];
    }

    // output results as html table
    NSMutableString *str = [NSMutableString string];

    [str appendString:@"<table>\n<thead>\n<tr><th>Name</th><th>Iterations</th><th>Total time (sec)</th><th>Time per (ns)</th></tr>\n</thead>\n<tbody>\n"];
    for (NSDictionary *result in testResults)
    {
        NSString *name = [result objectForKey: @"name"];
        int       iterations = [[result objectForKey: @"iterations"] intValue];
        double    total = [[result objectForKey: @"total"] doubleValue];
        double    each = [[result objectForKey: @"each"] doubleValue];

        [str appendFormat: @"<tr><td>%@</td><td>%d</td><td>%.1f</td><td>%.1f</td></tr>\n", name, iterations, total, each];
    }
    [str appendString: @"</tbody>\n</table>\n"];

    [(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}

// --------------------

- (double) machTimeToNanos:(uint64_t)time
{
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    return (double)time * (double)timebase.numer / (double)timebase.denom;
}

// time a single method
- (struct Result) timeForSelector:(SEL)sel
{
    double duration;
    @autoreleasepool
    {
        mStartTime = 0;
        mEndTime   = 0;
        [self performSelector:sel];
        duration = [self machTimeToNanos:(mEndTime - mStartTime)];
    }

    struct Result result = {
        mIterations,
        duration / 1000000000.0,
        duration / mIterations
    };
    return result;
}

// ----------------------------------------------------------------------------------------------

- (void) beginTest
{
    mStartTime = mach_absolute_time();
}

- (void) endTestWithIterations:(int)iters
{
    mEndTime    = mach_absolute_time();
    mIterations = iters;
}

#define BEGIN( count ) \
    int iters = count; \
    int i; \
    [self beginTest]; \
    for( i = 1; i <= iters; i++ )

#define END() \
    [self endTestWithIterations:iters];

// ----------------------------------------------------------------------------------------------

- (void) testNothing
{
    BEGIN(mIterations)
        ;
    END()
}

// --------------------

class StubClass
{
    public:
    virtual void stub() { }
};

- (void) testCPPVirtualCall
{
    class StubClass *obj = new StubClass;
    BEGIN( 1000000000 )
            obj->stub();
    END()
}

// --------------------

- (void) stubMethod
{
}

- (void) testMessaging
{
    BEGIN( 1000000000 )
            [self stubMethod];
    END()
}

- (void) testIMPCachedMessaging
{
    void (*imp)(id, SEL) = (void (*)(id, SEL)) [self methodForSelector:@selector(stubMethod)];
    BEGIN( 1000000000 )
            imp( self, @selector(stubMethod));
    END()
}

- (void) testNSInvocation
{
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(stubMethod)]];
    [invocation setSelector:@selector(stubMethod)];
    [invocation setTarget:self];

    BEGIN( 10000000 )
            [invocation invoke];
    END()
}

// --------------------

- (void) testIntDivision
{
    int x;

    BEGIN( 1000000000 )
        x = 1000000000 / i;
    END()
}

- (void) testFloatDivision
{
    double x;
    double y = 42.3;

    BEGIN( 100000000 )
        x = 100000000.0 / y;
    END()
}

- (void) testFloatConversionDivision
{
    double x;

    BEGIN( 100000000 )
        x = 1000000000.0 / i;
    END()
}

// --------------------

- (void) testObjectCreation
{
    BEGIN( 10000000 )
        [[NSObject alloc] init];
    END()
}

- (void) testPoolCreation
{
    BEGIN( 10000000 )
        @autoreleasepool
        {
        }
    END()
}

// --------------------

- (void) testSmallMallocFree
{
    BEGIN( 100000000 )
        free( malloc( 16 ) );
    END()
}

- (void) testLargeMallocFree
{
    BEGIN( 100000 )
        free( malloc( 1 << 24 ) );
    END()
}

// --------------------

- (void) testMemcpySize:(uint)size count:(int)count
{
    void *src = malloc( size );
    void *dst = malloc( size );
    BEGIN( count )
        memcpy( dst, src, size );
    END()
    free( src );
    free( dst );
}

- (void) testSmallMemcpy
{
    [self testMemcpySize:16 count:100000000];
}

- (void) testLargeMemcpy
{
    [self testMemcpySize:1 << 20 count:10000];
}

// --------------------

- (void) testWriteFileSize:(uint)size atomic:(BOOL)atomic count:(int)count
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"testrand"];

    NSData *data = [[NSFileHandle fileHandleForReadingAtPath:@"/dev/random"] readDataOfLength:size];

    BEGIN( count )
        [data writeToFile:path atomically:atomic];
    END()

    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (void) testWriteSmallFile
{
    [self testWriteFileSize:16 atomic:NO count:10000];
}

- (void) testWriteSmallFileAtomic
{
    [self testWriteFileSize:16 atomic:YES count:10000];
}

- (void) testWriteLargeFile
{
    [self testWriteFileSize:1 << 24 atomic:NO count:30];
}

- (void) testWriteLargeFileAtomic
{
    [self testWriteFileSize:1 << 24 atomic:YES count:30];
}

// --------------------

- (void) testReadFileSize:(uint)size count:(int)count
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"testrand"];
    
    NSData *data = [[NSFileHandle fileHandleForReadingAtPath:@"/dev/random"] readDataOfLength:size];
    [data writeToFile:path atomically:NO];

    BEGIN( count )
        [[NSData alloc] initWithContentsOfFile:path];
    END()

    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

- (void) testReadSmallFile
{
    [self testReadFileSize:16 count:100000];
}

- (void) testReadLargeFile
{
    [self testReadFileSize:1 << 24 count:100];
}

// --------------------

static void *stub_pthread( void * )
{
    return NULL;
}

- (void) testSpawnThread
{
    BEGIN( 10000 )
    {
        pthread_t pt;
        pthread_create( &pt, NULL, stub_pthread, NULL );
        pthread_join( pt, NULL );
    }
    END()
}

// --------------------

- (void) delayedPerform
{
    if( mIterations++ < 100000 )
        [self performSelector:@selector(delayedPerform) withObject:nil afterDelay:0.0];
    else
        CFRunLoopStop( CFRunLoopGetCurrent() );
}

- (void) testDelayedPerform
{
    [self beginTest];
    [self performSelector:@selector(delayedPerform) withObject:nil afterDelay:0.0];
    CFRunLoopRun();
    [self endTestWithIterations:100000];
}

// --------------------

- (void) testSetPropertyDirect
{
    _testDirect = 0;
    BEGIN( 1000000000 )
        _testDirect = i;
    END()
}

- (void) testUpdatePropertyDirect
{
    _testDirect = 0;
    BEGIN( 1000000000 )
        _testDirect ^= i;
    END()
}

- (void) testSetPropertyNonAtomic
{
    self.testNonAtomic = 0;
    BEGIN( 1000000000 )
        self.testNonAtomic = i;
    END()
}

- (void) testUpdatePropertyNonAtomic
{
    self.testNonAtomic = 0;
    BEGIN( 1000000000 )
        self.testNonAtomic = self.testNonAtomic ^ i;
    END()
}

- (void) testSetPropertyAtomic
{
    self.testAtomic = 0;
    BEGIN( 1000000000 )
        self.testAtomic = i;
    END()
}

- (void) testUpdatePropertyAtomic
{
    self.testAtomic = 0;
    BEGIN( 1000000000 )
    {
        self.testAtomic = self.testAtomic ^ i;

    }
    END()
}

@end


