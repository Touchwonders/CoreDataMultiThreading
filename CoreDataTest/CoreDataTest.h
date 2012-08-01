//
//  CoreDataTest.h
//  CoreDataTest
//
//  Created by Robin van Dijke on 01-08-12.
//  Copyright (c) 2012 Touchwonders B.V. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Simple class which demonstrates how to
 * use CoreData together with multithreading.
 *
 * Also contains some helpers function which may
 * be helpful in your code later on
 */

@interface CoreDataTest : NSObject {
    NSManagedObjectContext *_parentContext;     // parent managedObjectContext tied to the persistent store coordinator
    NSManagedObjectContext *_childContext;      // child managedObjectContext whichs runs in a background thread
}

/**
 * Sets up CoreData and demonstrates how the setup
 * works by triggering a large save block on the
 * child objectContext. After some time a call is
 * done to retrieve data from the parentObjectContext
 * which is able to pause the child block and displays the data
 * written until now in the console.
 */
- (void)coreDataTest;

@end
