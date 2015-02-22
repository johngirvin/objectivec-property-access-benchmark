
@interface BenchmarkCase : NSObject

@property (nonatomic) NSString *name;
@property (nonatomic) SEL       selector;

+ (BenchmarkCase *) caseWithName:(NSString *)name andSelector:(SEL)selector;

@end

