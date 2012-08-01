//
//  CoreDataTest.m
//  CoreDataTest
//
//  Created by Robin van Dijke on 01-08-12.
//  Copyright (c) 2012 Touchwonders B.V. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "CoreDataTest.h"
#import "Test.h"

@interface CoreDataTest (Helpers)

/**
 * Creates a new managedObject of the given type and keeps
 * threading into account. If called from the mainThread
 * it uses the parentContext. If called from a background thread
 * it uses the childContext. Here the assumption is made that you
 * only perform coredata calls using the performBlock: functions.
 * If not, another background thread may be used which is not
 * tied to the child context. Therefore, if you have to perform
 * a large operation on the background, always use performBlock:
 * on the childContext
 *
 * @param type Entity of the managedObject to create
 * @result Newly created managedObject
 */
- (NSManagedObject *)newManagedObjectOfType:(NSString *)type;

/**
 * Performs a synchronous fetchRequest. Selects the correct 
 * managedObjectContext using the same technique as described in
 * the newManagedObjectOfType: function
 *
 * @param type Entity to fetch
 * @param fetchRequestChangeBlock Here you can make modifications to the fetchRequest (e.g. adding predicates, setting batch sizes, etc)
 * @result Result of the fetchRequest
 */
- (NSArray *)entitiesOfType:(NSString *)type withFetchRequestChangeBlock:(NSFetchRequest * (^)(NSFetchRequest *))fetchRequestChangeBlock;

/**
 * Does the same as entitiesOfType:withFetchRequestChangeBlock: but also
 * contains a completionBlock because the request is performed asynchronously.
 *
 * @param type Entity to fetch
 * @param fetchRequestChangeBlock Here you can make modifications to the fetchRequest (e.g. adding predicates, setting batch sizes, etc)
 * @param completionBlock Block which is executed after a result has been obtained.
 */
- (void)entitiesOfType:(NSString *)type withFetchRequestChangeBlock:(NSFetchRequest *(^)(NSFetchRequest *))fetchRequestChangeBlock withCompletionBlock:(void (^)(NSArray *))completionBlock;

/**
 * Makes sure that the array of given managedObjects
 * is tied to the parentManagedObjectContext
 *
 * @param managedObjects Array of NSManagedObjects to convert the the parentContext
 * @result Converted objects
 */
- (NSArray *)convertManagedObjectsToMainContext:(NSArray *)managedObjects;
 
/**
 * Returns the application its documents directory
 *
 * @return URL
 */
- (NSURL *)applicationDocumentsDirectory;

@end

@implementation CoreDataTest

- (void)coreDataTest {
    // Create NSManagedObjectModel and NSPersistentStoreCoordinator
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Model" withExtension:@"momd"];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"store.sqlite"];
    
    // remove old store if exists
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[storeURL path]])
        [fileManager removeItemAtURL:storeURL error:nil];
    
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    NSPersistentStoreCoordinator *storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    [storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                   configuration:nil
                                             URL:storeURL
                                         options:nil
                                           error:nil];
    
    // create the parent NSManagedObjectContext with the concurrency type to NSMainQueueConcurrencyType
    _parentContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_parentContext setPersistentStoreCoordinator:storeCoordinator];
    
    // creat the child one with concurrency type NSPrivateQueueConcurrenyType
    _childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [_childContext setParentContext:_parentContext];
    
    // create a NSEntityDescription for the only entity in this CoreData model: Test
    NSEntityDescription *testDescription = [NSEntityDescription entityForName:@"Test"
                                                       inManagedObjectContext:_parentContext];
    
    // perform a heavy write block on the child context
    __block BOOL done = NO;
    [_childContext performBlock:^{
        for (int i = 0; i < 2000; i++){
            Test *test = [[Test alloc] initWithEntity:testDescription
                       insertIntoManagedObjectContext:_childContext];
            test.test = [NSString stringWithFormat:@"Test %d", i];
            NSLog(@"Create test %d", i);
            
            [_childContext save:nil];
        }
        
        done = YES;
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"Done write test: Saving parent");
            [_parentContext save:nil];
            
            // execute a fetch request on the parent to see the results
            NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"Test"];
            NSLog(@"Done: %d objects written", [[_parentContext executeFetchRequest:fr error:nil] count]);
        });
    }];
    
    // execute a read request after 1 second
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"Test"];
        [_parentContext performBlockAndWait:^{
            NSLog(@"In between read: read %d objects", [[_parentContext executeFetchRequest:fr error:nil] count]);
        }];
    });   
}

@end

@implementation CoreDataTest (Helpers)

#pragma mark - Applications Documents Directory
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - Generic Object Functions

- (NSManagedObject *)newManagedObjectOfType:(NSString *)type {
    NSManagedObjectContext *managedObjectContext = [NSThread isMainThread] ? _parentContext : _childContext;
    
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:type
                                                         inManagedObjectContext:managedObjectContext];
    if (entityDescription == nil)
        @throw [NSException exceptionWithName:@"CoreDataException"
                                       reason:@"EntityType does not exist"
                                     userInfo:nil];
    
    Class class = NSClassFromString(type);
    if (class == nil)
        @throw [NSException exceptionWithName:@"CoreDataException"
                                       reason:@"ClassType does not exist"
                                     userInfo:nil];
    
    return [[class alloc] initWithEntity:entityDescription
          insertIntoManagedObjectContext:managedObjectContext];
}

- (NSArray *)entitiesOfType:(NSString *)type withFetchRequestChangeBlock:(NSFetchRequest * (^)(NSFetchRequest *))fetchRequestChangeBlock {
    NSManagedObjectContext *managedObjectContext = [NSThread isMainThread] ? _parentContext : _childContext;
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:type];
    if (fetchRequest == nil)
        @throw [NSException exceptionWithName:@"CoreDataException"
                                       reason:@"EntityType does not exist"
                                     userInfo:nil];
    
    if (fetchRequestChangeBlock != nil)
        fetchRequest = fetchRequestChangeBlock(fetchRequest);
    
    __block NSError *error = nil;
    __block NSArray *result = nil;
    [managedObjectContext performBlockAndWait:^{
        result = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    }];
    
    if (error != nil){
        NSLog(@"Error while fetching results: %@", error);
        return nil;
    }

    return result;
}

- (void)entitiesOfType:(NSString *)type withFetchRequestChangeBlock:(NSFetchRequest *(^)(NSFetchRequest *))fetchRequestChangeBlock withCompletionBlock:(void (^)(NSArray *))completionBlock {
    
    if (completionBlock == nil) return;
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:type];
    if (fetchRequest == nil)
        @throw [NSException exceptionWithName:@"CoreDataException"
                                       reason:@"EntityType does not exist"
                                     userInfo:nil];
    
    if (fetchRequestChangeBlock != nil)
        fetchRequest = fetchRequestChangeBlock(fetchRequest);
    
    [_childContext performBlock:^{
        NSError *error = nil;
        NSArray *result = [_childContext executeFetchRequest:fetchRequest error:&error];
        
        if (error != nil){
            NSLog(@"Error while fetching background results: %@", error);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil);
            });
        }
        
        result = [self convertManagedObjectsToMainContext:result];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(result);
        });
    }];
}

- (NSArray *)convertManagedObjectsToMainContext:(NSArray *)managedObjects {
    // convert the products to the mainObjectContext
    if ([managedObjects count] > 0){
        NSMutableArray *mainObjects = [NSMutableArray arrayWithCapacity:[managedObjects count]];
        for (NSManagedObject *object in managedObjects){
            if (![object isKindOfClass:[NSManagedObject class]])
                @throw [NSException exceptionWithName:@"CoreDataException"
                                               reason:@"Error while converting objects, must be a NSManagedObject"
                                             userInfo:[NSDictionary dictionaryWithObject:object forKey:@"Object"]];
            
            NSManagedObjectID *objectId = [object objectID];
            [mainObjects addObject:[_parentContext objectWithID:objectId]];
        }
        
        return [NSArray arrayWithArray:mainObjects];
    }
    
    return managedObjects;
}

@end
