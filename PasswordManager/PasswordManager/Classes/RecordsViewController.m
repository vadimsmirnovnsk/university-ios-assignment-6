//
//  RecordsViewController.m
//  PasswordManager
//
//  Created by Maxim Zabelin on 20/02/14.
//  Copyright (c) 2014 Noveo. All rights reserved.
//

#import "NewRecordViewController.h"
#import "Record.h"
#import "RecordsManager.h"
#import "RecordsViewController.h"
#import "OptionsViewController.h"
#import "Preferences.h"

static NSString *const DefaultFileNameForLocalStore = @"AwesomeFileName.dat";
static NSString *const DefaultCodedFileNameForLocalStore = @"AwesomeCodedFileName.dat";
static NSString *const DefaultDBFileNameForLocalStore = @"AwesomeDB.db";

@interface RecordsViewController ()
    <UITableViewDataSource,
     UITableViewDelegate,
     NewRecordViewControllerDelegate,
     OptionsViewControllerDelegate>

@property (nonatomic, readonly) RecordsManager *recordsManager;
@property (nonatomic, readonly) RecordsManager *recordsDbManager;
@property (nonatomic, readonly) RecordsManager *recordsEncodedManager;
@property (nonatomic, readonly) RecordsManager *recordsPlistManager;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

- (IBAction)didTouchAddBarButtonItem:(UIBarButtonItem *)sender;
- (IBAction)didTouchOptionsBarButtonItem:(UIBarButtonItem *)sender;

@end

@implementation RecordsViewController

@synthesize recordsManager = recordsManager_;
@synthesize recordsDbManager = recordsDbManager_;
@synthesize recordsEncodedManager = recordsEncodedManager_;
@synthesize recordsPlistManager = recordsPlistManager_;

@synthesize tableView = tableView_;

#pragma mark - Init
- (instancetype) init
{
    if (self = [super init]) {
        NSURL *const documentDirectoryURL =
            [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                    inDomains:NSUserDomainMask] lastObject];
        NSURL *const libraryDirectoryURL =
            [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory
                                                    inDomains:NSUserDomainMask] lastObject];
        NSURL *fileURLForLocalStore = nil;
        
        fileURLForLocalStore = [libraryDirectoryURL URLByAppendingPathComponent:DefaultDBFileNameForLocalStore];
        recordsPlistManager_ = [[RecordsManager alloc] initWithURL:fileURLForLocalStore];
        
        fileURLForLocalStore = [libraryDirectoryURL URLByAppendingPathComponent:DefaultDBFileNameForLocalStore];
        recordsDbManager_ = [[RecordsManager alloc] initWithURL:fileURLForLocalStore];
        
        fileURLForLocalStore = [documentDirectoryURL URLByAppendingPathComponent:DefaultCodedFileNameForLocalStore];
        recordsEncodedManager_ = [[RecordsManager alloc] initWithURL:fileURLForLocalStore];
        
    }
    return self;
}

#pragma mark - Getters

- (RecordsManager *)recordsManager
{
    switch ([[Preferences standardPreferences]keepingMode]) {
        case KeepingModeEncoded:
            recordsManager_ = recordsEncodedManager_;
            break;
            
        case KeepingModeFmdb:
            recordsManager_ = recordsDbManager_;
        break;
        
        case KeepingModePlist:
        default:
            recordsManager_ = recordsPlistManager_;
            break;
    }
    return recordsManager_;
}

#pragma mark - Actions

- (IBAction)didTouchAddBarButtonItem:(UIBarButtonItem *)sender
{
    NewRecordViewController *const rootViewController = [[NewRecordViewController alloc] init];
    rootViewController.delegate = self;

    UINavigationController *const navigationController =
        [[UINavigationController alloc] initWithRootViewController:rootViewController];
    [self presentViewController:navigationController animated:YES completion:NULL];
}

- (IBAction)didTouchOptionsBarButtonItem:(UIBarButtonItem *)sender
{
    OptionsViewController *const rootViewController = [[OptionsViewController alloc] init];
    [rootViewController setDelegate:self];

    UINavigationController *const navigationController =
        [[UINavigationController alloc] initWithRootViewController:rootViewController];
    [self presentViewController:navigationController animated:YES completion:NULL];
}

#pragma mark - UITableViewDataSource implementation

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return [[self.recordsManager records] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
#define REUSABLE_CELL_ID @"ReusableCellID"

    UITableViewCell *tableViewCell =
        [tableView dequeueReusableCellWithIdentifier:REUSABLE_CELL_ID];
    if (!tableViewCell) {
        tableViewCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                               reuseIdentifier:REUSABLE_CELL_ID];
    }
    NSDictionary *const record =
        [[self.recordsManager records] objectAtIndex:indexPath.row];
    tableViewCell.textLabel.text = [record valueForKey:kServiceName];
    tableViewCell.detailTextLabel.text = [record valueForKey:kPassword];

    return tableViewCell;

#undef REUSABLE_CELL_ID
}

- (BOOL) tableView:tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}


- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
    NSDictionary *const record =
        [[self.recordsManager records] objectAtIndex:indexPath.row];
        [self.recordsManager deleteRecord:record];
        [self.recordsManager synchronize];
        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [tableView endUpdates];
    }
}

#pragma mark - UITableViewDelegate implementation

-       (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NewRecordViewController *const rootViewController =
        [[NewRecordViewController alloc] initWithRecord:
            [[self.recordsManager records] objectAtIndex:indexPath.row]];
    rootViewController.delegate = self;
    
    NSDictionary *const record =
    [[self.recordsManager records] objectAtIndex:indexPath.row];
    [self.recordsManager deleteRecord:record];
    
    UINavigationController *const navigationController =
        [[UINavigationController alloc] initWithRootViewController:rootViewController];
    [self presentViewController:navigationController animated:YES completion:NULL];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - NewRecordViewControllerDelegate implementation

- (void)newRecordViewController:(NewRecordViewController *)sender
            didFinishWithRecord:(NSDictionary *)record
{
    if (record) {
        [self.recordsManager registerRecord:record];
        if ([self.recordsManager synchronize]) {
            NSLog(@"Successfull synchronized");
        }
        else {
            NSLog(@"Synchronization error!");
        }
        [self.tableView reloadData];
    }
    [self dismissViewControllerAnimated:YES
                             completion:NULL];
}

#pragma mark - OptionsViewControllerDelegate implementation

- (void)didCloseOptionsMenu:(OptionsViewController *)sender
{
    [sender dismissViewControllerAnimated:YES
                               completion:NULL];
    [self.tableView reloadData];
}

#pragma mark ShouldUpdateDelegate implementation

- (void) updateDefaults:(id)sender
{
    [self didCloseOptionsMenu:nil];
}


@end
