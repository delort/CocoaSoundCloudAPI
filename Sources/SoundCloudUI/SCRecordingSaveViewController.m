//
//  SCRecordingSaveViewController.m
//  Soundcloud
//
//  Created by Gernot Poetsch on 25.10.10.
//  Copyright 2010 nxtbgthng. All rights reserved.
//

#import "QuartzCore_GPKit.h"
#import "UIImage_GPKit.h"
#import "SCSwitch.h"
#import "GPTableCellBackgroundView.h"
#import "GPURLConnection.h"

#import "JSONKit.h"

#import "SCSharingMailPickerController.h"
#import "SCFoursquarePlacePickerController.h"
#import "SCConstants.h"
#import "SCAddConnectionViewController.h"
#import "SCAccount.h"
#import "SCRequest.h"

#import "SCBundle.h"
#import "SCSCRecordingSaveViewControllerTitleView.h"
#import "SCRecordingSaveViewControllerHeaderView.h"
#import "SCRecordingUploadProgressView.h"

#import "SCRecordingSaveViewController.h"


#define COVER_WIDTH 600.0
#define TEXTBOX_LEFT 102.0
#define TEXTBOX_RIGHT 9.0
#define TEXTBOX_TOP 9.0
#define TEXTBOX_HEIGHT 84.0


@interface SCRecordingSaveViewController ()

#pragma mark Accessors
@property (nonatomic, retain) NSArray *availableConnections;
@property (nonatomic, retain) NSArray *unconnectedServices;
@property (nonatomic, retain) NSArray *sharingConnections;
@property (nonatomic, retain) NSArray *sharingMailAddresses;
@property (nonatomic, retain) CLLocation *location;
@property (nonatomic, copy) NSString *locationTitle;
@property (nonatomic, copy) NSString *foursquareID;
@property (nonatomic, retain) NSURL *fileURL;
@property (nonatomic, retain) NSData *fileData;
@property (nonatomic, retain) SCAccount *account;
@property (nonatomic, retain) UIImage *coverImage;
@property (nonatomic, assign) BOOL isPrivate;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, copy) SCRecordingSaveViewControllerCompletionHandler completionHandler;
@property (nonatomic, retain) SCFoursquarePlacePickerController *foursquareController;

@property (nonatomic, assign) SCRecordingSaveViewControllerHeaderView *headerView;
@property (nonatomic, assign) SCRecordingUploadProgressView *uploadProgressView;

#pragma mark UI
- (void)updateInterface;

#pragma mark Actions
- (IBAction)shareConnectionSwitchToggled:(id)sender;
- (IBAction)openCameraPicker;
- (IBAction)openImageLibraryPicker;
- (IBAction)openPlacePicker;
- (IBAction)closePlacePicker;
- (IBAction)privacyChanged:(id)sender;
- (IBAction)selectImage;
- (IBAction)resetImage;
- (IBAction)upload;
- (IBAction)cancel;
- (IBAction)logout;
@end


NSString * const SCDefaultsKeyRecordingIsPrivate = @"SCRecordingIsPrivate";


@implementation SCRecordingSaveViewController


#pragma mark Class methods

const NSArray *allServices = nil;

+ (void)initialize;
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
															 [NSNumber numberWithBool:NO], SCDefaultsKeyRecordingIsPrivate,
															 nil]];
    allServices = [[NSArray alloc] initWithObjects:
                   [NSDictionary dictionaryWithObjectsAndKeys:
                    NSLocalizedString(@"service_twitter", @"Twitter"), @"displayName",
                    @"twitter", @"service",
                    nil],
                   [NSDictionary dictionaryWithObjectsAndKeys:
                    NSLocalizedString(@"service_facebook", @"Facebook"), @"displayName",
                    @"facebook_profile", @"service",
                    nil],
                   [NSDictionary dictionaryWithObjectsAndKeys:
                    NSLocalizedString(@"service_tumblr", @"Tumblr"), @"displayName",
                    @"tumblr", @"service",
                    nil],
                   [NSDictionary dictionaryWithObjectsAndKeys:
                    NSLocalizedString(@"service_foursquare", @"Foursquare"), @"displayName",
                    @"foursquare", @"service",
                    nil],
                   nil];
}


@synthesize availableConnections;
@synthesize unconnectedServices;
@synthesize sharingConnections;
@synthesize sharingMailAddresses;
@synthesize locationTitle;
@synthesize location;
@synthesize foursquareID;
@synthesize fileURL;
@synthesize fileData;
@synthesize account;
@synthesize coverImage;
@synthesize isPrivate;
@synthesize title;
@synthesize completionHandler;
@synthesize foursquareController;
@synthesize headerView;
@synthesize uploadProgressView;


#pragma mark Lifecycle

- (id)init;
{
    if ((self = [super initWithNibName:@"RecordingSave" bundle:nil])) {
        
        self.hidesBottomBarWhenPushed = YES;
        self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"navigation_back", @"Back")
                                                                                  style:UIBarButtonItemStyleBordered
                                                                                 target:nil
                                                                                 action:nil] autorelease];
        
        [self.navigationController setToolbarHidden:YES];

        
        self.availableConnections = [NSArray array];
        self.unconnectedServices = [NSArray array];
        self.sharingConnections = [NSArray array];
        self.sharingMailAddresses = [NSArray array];
        
        self.isPrivate = [[NSUserDefaults standardUserDefaults] boolForKey:SCDefaultsKeyRecordingIsPrivate];
        self.location = nil;
        self.locationTitle = nil;
        self.foursquareID = nil;
        
        self.account = nil;
        
        self.coverImage = nil;
        self.title = nil;
        
        self.completionHandler = nil;
    }
    return self;
}

- (void)dealloc;
{
    [availableConnections release];
    [unconnectedServices release];
    [sharingConnections release];
    [sharingMailAddresses release];
    [location release];
    [locationTitle release];
    [foursquareID release];
    [account release];
    [coverImage release];
    [title release];
    [completionHandler release];
    [foursquareController release];
    
    [super dealloc];
}


#pragma mark Accessors

- (void)setFileURL:(NSURL *)aFileURL;
{
    if (fileURL != aFileURL) {
        [fileURL release];
        [aFileURL retain];
        fileURL = aFileURL;
    }
}

- (void)setFileData:(NSData *)someFileData;
{
    if (fileData != someFileData) {
        [fileData release];
        [someFileData retain];
        fileData = someFileData;
    }
}

- (void)setAccount:(SCAccount *)anAccount;
{
    if (account != anAccount) {
        [account release];
        [anAccount retain];
        account = anAccount;
        
        [SCRequest performMethod:SCRequestMethodGET
                      onResource:[NSURL URLWithString:@"https://api.soundcloud.com/me/connections.json"]
                 usingParameters:nil
                     withAccount:account
          sendingProgressHandler:nil
                 responseHandler:^(NSURLResponse *response, NSData *data, NSError *error){
                     if (data) {
                         NSError *jsonError = nil;
                         NSArray *result = [data objectFromJSONData];
                         if (result) {
                             [self setAvailableConnections:result];
                         } else {
                             NSLog(@"%s json error: %@", __FUNCTION__, [jsonError localizedDescription]);
                         }
                     } else {
                         NSLog(@"%s error: %@", __FUNCTION__, [error localizedDescription]);
                     }
                 }];
        
        [SCRequest performMethod:SCRequestMethodGET
                      onResource:[NSURL URLWithString:@"https://api.soundcloud.com/me.json"]
                 usingParameters:nil
                     withAccount:account
          sendingProgressHandler:nil
                 responseHandler:^(NSURLResponse *response, NSData *data, NSError *error){
                     if (data) {
                         NSError *jsonError = nil;
                         id result = [data objectFromJSONData];
                         if (result) {
                             NSLog(@"Me: %@", result);
                             
                             NSURL *avatarURL = [NSURL URLWithString:[result objectForKey:@"avatar_url"]];
                             NSData *avatarData = [NSData dataWithContentsOfURL:avatarURL];
                             [self.headerView setAvatarImage:[UIImage imageWithData:avatarData]];
                             [self.headerView setUserName:[result objectForKey:@"username"]];
                             
                         } else {
                             NSLog(@"%s json error: %@", __FUNCTION__, [jsonError localizedDescription]);
                         }
                     } else {
                         NSLog(@"%s error: %@", __FUNCTION__, [error localizedDescription]);
                     }
                 }];
    }
}

- (void)setPrivate:(BOOL)p;
{
    isPrivate = p;
}

- (void)setCoverImage:(UIImage *)aCoverImage;
{
    if (coverImage != aCoverImage) {
        [coverImage release];
        [aCoverImage retain];
        coverImage = aCoverImage;
        [self.headerView setCoverImage:aCoverImage];
    }
}

- (void)setTitle:(NSString *)aTitle;
{
    if (title != aTitle) {
        [title release];
        [aTitle retain];
        title = aTitle;
    }
}

- (void)setAvailableConnections:(NSArray *)value;
{
    [value retain]; [availableConnections release]; availableConnections = value;
    
    NSMutableArray *newUnconnectedServices = [allServices mutableCopy];
    
    //Set the unconnected Services
    for (NSDictionary *connection in availableConnections) {
        NSDictionary *connectedService = nil;
        for (NSDictionary *unconnectedService in newUnconnectedServices) {
            if ([[connection objectForKey:@"service"] isEqualToString:[unconnectedService objectForKey:@"service"]]) {
                connectedService = unconnectedService;
            }
        }
        if (connectedService) [newUnconnectedServices removeObject:connectedService];
    }
    
    self.unconnectedServices = newUnconnectedServices;
    [newUnconnectedServices release];
    [tableView reloadData];
}

#pragma mark Foursquare

- (void)setFoursquareClientID:(NSString *)aClientID clientSecret:(NSString *)aClientSecret;
{
    self.foursquareController = [[[SCFoursquarePlacePickerController alloc] initWithDelegate:self
                                                                                    clientID:aClientID
                                                                                clientSecret:aClientSecret] autorelease];
    
    self.foursquareController.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                                                target:self
                                                                                                                action:@selector(closePlacePicker)] autorelease];
}


#pragma mark ViewController

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    // Toolbar
    self.navigationController.toolbar.barStyle = UIBarStyleBlack;
    self.navigationController.toolbarHidden = NO;
    
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithCapacity:3];
    
    [toolbarItems addObject:[[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"cancel", @"Cancel")
                                                              style:UIBarButtonItemStyleBordered
                                                             target:self
                                                             action:@selector(cancel)] autorelease]];
    
    [toolbarItems addObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease]];
    
    [toolbarItems addObject:[[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"upload_and_share", @"Upload & Share")
                                                              style:UIBarButtonItemStyleBordered
                                                             target:self
                                                             action:@selector(upload)] autorelease]];
    
    [self setToolbarItems:toolbarItems];
    
    // Background
    self.view.backgroundColor = [UIColor colorWithPatternImage:[SCBundle imageFromPNGWithName:@"darkTexturedBackgroundPattern"]];
    
    // Banner
    [self.view addSubview:[[[SCSCRecordingSaveViewControllerTitleView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 28.0)] autorelease]];
    
    // Table View
    self.headerView = [[[SCRecordingSaveViewControllerHeaderView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(tableView.bounds), 0)] autorelease];
    
    self.headerView.whatTextField.delegate = self;
    self.headerView.whereTextField.delegate = self;
    
    [self.headerView.coverImageButton addTarget:self
                                         action:@selector(selectImage)
                               forControlEvents:UIControlEventTouchUpInside];
    
    [self.headerView.privateSwitch addTarget:self
                                      action:@selector(privacyChanged:)
                            forControlEvents:UIControlEventValueChanged];
    
    [self.headerView.disclosureButton addTarget:self
                                         action:@selector(openPlacePicker)
                               forControlEvents:UIControlEventTouchUpInside];
    
    [self.headerView.logoutButton addTarget:self
                                     action:@selector(logout)
                           forControlEvents:UIControlEventTouchUpInside];
    
    tableView.tableHeaderView = self.headerView;
    
    
    
    CGRect newTableViewFrame = tableView.frame;
    newTableViewFrame.origin.y += 28.0;
    newTableViewFrame.size.height -= newTableViewFrame.origin.y;
    tableView.frame = newTableViewFrame;
    
    NSLog(@"table view frame: %@", NSStringFromCGRect(tableView.frame));
    
    tableView.backgroundColor = [UIColor colorWithPatternImage:[SCBundle imageFromPNGWithName:@"darkTexturedBackgroundPattern"]];
    

    
    
    [self updateInterface];
}

- (void)viewWillAppear:(BOOL)animated;
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBarHidden = YES;
    
    [tableView reloadData];
    
    self.headerView.whatTextField.text = self.title;
    self.headerView.whereTextField.text = self.locationTitle;
}

- (void)viewWillDisappear:(BOOL)animated;
{
    [super viewWillDisappear:animated];
    self.title = self.headerView.whatTextField.text;
    self.locationTitle = self.headerView.whereTextField.text;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation;
{
    return YES;
    if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation)) {
        return YES;
    }
    return NO;
}

- (void)updateInterface;
{
    self.headerView.whatTextField.text = self.title;
    self.headerView.whereTextField.text = self.locationTitle;
    self.headerView.privateSwitch.on = !isPrivate;
    [self.headerView setCoverImage:self.coverImage];
}


#pragma mark TableView

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section;
{
    if (isPrivate){
        return 1;
    } else {
        return self.availableConnections.count + self.unconnectedServices.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    if (isPrivate) {
        UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:@"mailShare"];
        if (!cell) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"mailShare"] autorelease];
            GPTableCellBackgroundView *backgroundView = [[[GPTableCellBackgroundView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 44.0)] autorelease];
            backgroundView.backgroundColor = aTableView.backgroundColor;
            backgroundView.borderColor = [UIColor colorWithWhite:0.27 alpha:1.0];
            cell.backgroundView = backgroundView;
            cell.textLabel.backgroundColor = aTableView.backgroundColor;
            cell.textLabel.font = [UIFont systemFontOfSize:16.0];
            cell.textLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
            cell.textLabel.highlightedTextColor = [UIColor whiteColor];
            cell.detailTextLabel.backgroundColor = aTableView.backgroundColor;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:16.0];
            cell.detailTextLabel.textColor = [UIColor whiteColor];
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
        }
                
        cell.textLabel.text = NSLocalizedString(@"sc_upload_with_access", @"With access");
        if (self.sharingMailAddresses.count == 0) {
            cell.detailTextLabel.text = NSLocalizedString(@"sc_upload_only_you", @"Only you");
        } else {
            cell.detailTextLabel.text = [self.sharingMailAddresses componentsJoinedByString:@", "];
        }

        [(GPTableCellBackgroundView *)cell.backgroundView setPosition:[aTableView cellPositionForIndexPath:indexPath]];
        
        return cell;
        
    } else {
        if (indexPath.row < availableConnections.count) {
            UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:@"connection"];
            if (!cell) {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"connection"] autorelease];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                GPTableCellBackgroundView *backgroundView = [[[GPTableCellBackgroundView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 44.0)] autorelease];
                backgroundView.backgroundColor = aTableView.backgroundColor;
                backgroundView.borderColor = [UIColor colorWithWhite:0.27 alpha:1.0];
                cell.backgroundView = backgroundView;
                cell.textLabel.backgroundColor = aTableView.backgroundColor;
                cell.textLabel.font = [UIFont systemFontOfSize:16.0];
                cell.textLabel.textColor = [UIColor whiteColor];
            }
            
            
            NSDictionary *connection = [availableConnections objectAtIndex:indexPath.row];
            
            cell.textLabel.text = [connection objectForKey:@"display_name"];
            
            SCSwitch *accessorySwitch = [[[SCSwitch alloc] init] autorelease];
            accessorySwitch.offBackgroundImage = [[SCBundle imageFromPNGWithName:@"switch_gray"] stretchableImageWithLeftCapWidth:5 topCapHeight:5];
            
            accessorySwitch.on = NO;
            [self.sharingConnections enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
                if ([[obj objectForKey:@"id"] isEqual:[connection objectForKey:@"id"]]) {
                    if (self.foursquareID || ![[connection objectForKey:@"service"] isEqualToString:@"foursquare"]) {
                        accessorySwitch.on = YES;
                    }
                    *stop = YES;
                }
            }];
            
            [accessorySwitch addTarget:self action:@selector(shareConnectionSwitchToggled:) forControlEvents:UIControlEventValueChanged];
            
            cell.accessoryView = accessorySwitch;
            
            cell.imageView.image = [SCBundle imageFromPNGWithName:[NSString stringWithFormat:@"service_%@", [connection objectForKey:@"service"]]];
            
            [(GPTableCellBackgroundView *)cell.backgroundView setPosition:[aTableView cellPositionForIndexPath:indexPath]];
            
            return cell;
        } else {
            UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:@"newConnection"];
            if (!cell) {
                cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"newConnection"] autorelease];
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
                GPTableCellBackgroundView *backgroundView = [[[GPTableCellBackgroundView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 44.0)] autorelease];
                backgroundView.backgroundColor = aTableView.backgroundColor;
                backgroundView.borderColor = [UIColor colorWithWhite:0.27 alpha:1.0];
                cell.backgroundView = backgroundView;
                cell.textLabel.backgroundColor = aTableView.backgroundColor;
                cell.textLabel.font = [UIFont systemFontOfSize:16.0];
                cell.textLabel.textColor = [UIColor whiteColor];
                cell.accessoryView = [[UIImageView alloc] initWithImage:[SCBundle imageFromPNGWithName:@"DisclosureIndicator"]];
                cell.detailTextLabel.text = NSLocalizedString(@"configure", @"Configure");
                cell.detailTextLabel.textColor = [UIColor whiteColor];
                cell.detailTextLabel.backgroundColor = aTableView.backgroundColor;
            }
            
            NSDictionary *service = [unconnectedServices objectAtIndex:indexPath.row - availableConnections.count];
            cell.textLabel.text = [service objectForKey:@"displayName"];
            cell.imageView.image = [SCBundle imageFromPNGWithName:[NSString stringWithFormat:@"service_%@", [service objectForKey:@"service"]]];
            
            [(GPTableCellBackgroundView *)cell.backgroundView setPosition:[aTableView cellPositionForIndexPath:indexPath]];
            return cell;
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
{
    return NSLocalizedString(@"sc_upload_sharing_options", @"Sharing Options");
}

- (UIView *)tableView:(UITableView *)aTableView viewForHeaderInSection:(NSInteger)section;
{
    UIView *sectionHeaderView = [[[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 20.0)] autorelease];
    sectionHeaderView.backgroundColor = aTableView.backgroundColor;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(sectionHeaderView.bounds, 10.0, 0.0)];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.backgroundColor = aTableView.backgroundColor;
    label.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    label.font = [UIFont systemFontOfSize:15.0];
    label.text = [self tableView:aTableView titleForHeaderInSection:section];
    [sectionHeaderView addSubview:label];
    [label release];
    return sectionHeaderView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
{
    return 28.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section;
{
    if (isPrivate) {
        return nil;
    } else {
        if (availableConnections.count == 0) {
            return nil; // @"To add sharing options, go to your settings on SoundCloud.com and select 'Connections'";
        } else {
            return NSLocalizedString(@"connection_list_footer", @"To change your default sharing options, go to your settings on SoundCloud and select 'Connections'");
        }
    }
}

- (UIView *)tableView:(UITableView *)aTableView viewForFooterInSection:(NSInteger)section;
{
    if (isPrivate) {
        return nil;
    } else {
        UIView *footerView = [[[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 20.0)] autorelease];
        footerView.backgroundColor = aTableView.backgroundColor;
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(footerView.bounds, 10.0, 0.0)];
        label.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        label.backgroundColor = aTableView.backgroundColor;
        label.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        label.font = [UIFont systemFontOfSize:13.0];
        label.text = [self tableView:aTableView titleForFooterInSection:section];
        label.numberOfLines = 2;
        [footerView addSubview:label];
        [label release];
        return footerView;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;
{
    return 48.0;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
{
    if (isPrivate) {
        if (indexPath.section == 0 && indexPath.row == 0) {
            SCSharingMailPickerController  *controller = [[SCSharingMailPickerController alloc] initWithDelegate:self];
			UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
			navController.navigationBar.barStyle = self.navigationController.navigationBar.barStyle;
			controller.title = NSLocalizedString(@"sc_upload_with_access", @"With Access");
			controller.result = self.sharingMailAddresses;
            [self presentModalViewController:navController animated:YES];
			[controller release];
			[navController release];
            
            [aTableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    } else {
        if (indexPath.row >= availableConnections.count) {
            NSDictionary *service = [unconnectedServices objectAtIndex:indexPath.row - availableConnections.count];
            SCAddConnectionViewController *controller = [[SCAddConnectionViewController alloc] initWithService:[service objectForKey:@"service"] account:account delegate:self];
            controller.title = [NSString stringWithFormat:NSLocalizedString(@"sc_upload_connect_to", @"Connect %@"), [service objectForKey:@"displayName"]];
            
            [self.navigationController pushViewController:controller animated:YES];
            [controller release];
            [aTableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    }
}


#pragma mark SCSharingMailPickerControllerDelegate

- (void)sharingMailPickerController:(SCSharingMailPickerController *)controller didFinishWithResult:(NSArray *)emailAdresses;
{
    self.sharingMailAddresses = emailAdresses;
    [tableView reloadData];
    [self dismissModalViewControllerAnimated:YES];
}

- (void)sharingMailPickerControllerDidCancel:(SCSharingMailPickerController *)controller;
{
    [self dismissModalViewControllerAnimated:YES];
}


#pragma mark UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string;
{    
    NSString *text = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    if (textField == self.headerView.whatTextField) {
        self.title = text;
    } else if (textField == self.headerView.whereTextField) {
        self.locationTitle = text;
    }
    return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField;
{
    if (textField == self.headerView.whatTextField) {
        self.title = textField.text;
    } else if (textField == self.headerView.whereTextField) {
        self.locationTitle = textField.text;
    }
    return YES;
}


- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField;
{
    if (textField == self.headerView.whereTextField) {
        [self.headerView.whatTextField resignFirstResponder]; //So we don't get the keyboard when coming back
        [self openPlacePicker];
        return NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField;
{
    [textField resignFirstResponder];
    return NO;
}


#pragma mark ActionSheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex;
{
    if (buttonIndex == actionSheet.firstOtherButtonIndex) {
        [self openImageLibraryPicker];  
    } else if (buttonIndex == actionSheet.firstOtherButtonIndex + 1
               && [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera].count > 0) {
        [self openCameraPicker];
    } else if (buttonIndex == actionSheet.destructiveButtonIndex) {
        [self resetImage];
    }
    
    [self updateInterface];
}


#pragma mark Image Picker Delegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo;
{
    UIImage *actualImage = image;
    if (!CGSizeEqualToSize(actualImage.size, CGSizeMake(COVER_WIDTH, COVER_WIDTH))) {
        actualImage = [actualImage imageByResizingTo:CGSizeMake(COVER_WIDTH, COVER_WIDTH)];
    }
    
    self.coverImage = actualImage;
    [self dismissModalViewControllerAnimated:YES];
}


#pragma mark Place Picker Delegate

- (void)foursquarePlacePicker:(SCFoursquarePlacePickerController *)aPicker
           didFinishWithTitle:(NSString *)aTitle
                 foursquareID:(NSString *)aFoursquareID
                     location:(CLLocation *)aLocation;
{
    self.headerView.whereTextField.text = aTitle;
    self.locationTitle = aTitle;
    self.location = aLocation;
    self.foursquareID = aFoursquareID;
    
    [self dismissModalViewControllerAnimated:YES];
}


#pragma mark Add Connection Delegate

- (void)addConnectionController:(SCAddConnectionViewController *)controller didFinishWithService:(NSString *)service success:(BOOL)success;
{
    if (success) {
        NSMutableArray *newUnconnectedServices = [NSMutableArray array];
        [self.unconnectedServices enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
            if (![[obj objectForKey:@"service"] isEqualToString:service]) {
                [newUnconnectedServices addObject:obj];
            }
        }];
        self.unconnectedServices = newUnconnectedServices;
        [tableView reloadData];
    }
    if (self.navigationController.topViewController == controller) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}


#pragma mark Actions

- (IBAction)shareConnectionSwitchToggled:(SCSwitch *)sender
{
    UITableViewCell *cell = (UITableViewCell *)[(UIView *)sender superview];
    NSIndexPath *indexPath = [tableView indexPathForCell:cell];
    
    NSDictionary *connection = [availableConnections objectAtIndex:indexPath.row];
    
    //If this is a foursquare switch, we don't have a venue and want to switch it on, display place picker
    if ([[connection objectForKey:@"service"] isEqualToString:@"foursquare"] && !self.foursquareID && [sender isOn]) {
        [self openPlacePicker];
    }
    
    NSMutableArray *newSharingConnections = [self.sharingConnections mutableCopy];
    if ([sender isOn]) {
        [newSharingConnections addObject:connection];
    } else {
        NSIndexSet *idxs = [newSharingConnections indexesOfObjectsPassingTest:^(id obj, NSUInteger i, BOOL *stop){
            if ([[obj objectForKey:@"id"] isEqual:[connection objectForKey:@"id"]]) {
                *stop = YES;
                return YES;
            } else {
                return NO;
            }
        }];
        [newSharingConnections removeObjectsAtIndexes:idxs];
    }
    
    self.sharingConnections = newSharingConnections;
    [newSharingConnections release];
}

- (IBAction)privacyChanged:(id)sender;
{
    if (sender == self.headerView.privateSwitch) {
		isPrivate = !self.headerView.privateSwitch.on;
        [[NSUserDefaults standardUserDefaults] setBool:!self.headerView.privateSwitch.on forKey:SCDefaultsKeyRecordingIsPrivate];
        [tableView reloadData];
    }
}

- (IBAction)selectImage;
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"recording_image", @"Cover Image")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"cancel", @"Cancel")
                                         destructiveButtonTitle:self.coverImage ? NSLocalizedString(@"artwork_reset", @"Reset") : nil
                                              otherButtonTitles:
                            ([UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary].count > 0) ? NSLocalizedString(@"use_existing_image", @"Photo Library") : nil,
                            ([UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera].count > 0) ? NSLocalizedString(@"take_new_picture", @"Camera") : nil,
                            nil];
    [sheet showInView:self.view];
    [sheet release];
}

- (IBAction)openCameraPicker;
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.allowsEditing = YES;
    [self presentModalViewController:picker animated:YES];
    [picker release];
}

- (IBAction)openImageLibraryPicker;
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentModalViewController:picker animated:YES];
    [picker release];
}

- (IBAction)openPlacePicker;
{
    if (self.foursquareController) {
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.foursquareController];
        navController.navigationBar.barStyle = self.navigationController.navigationBar.barStyle;
        [self presentModalViewController:navController animated:YES];
        [navController release];
    }
}

- (IBAction)closePlacePicker;
{
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)resetImage;
{
    self.coverImage = nil;
}

- (IBAction)upload;
{
    // TODO: Upload file
    NSLog(@"Uploading ...");
    
    tableView.hidden = YES;
    [self.navigationController setToolbarHidden:YES animated:YES];

    if (self.uploadProgressView) {
        [self.uploadProgressView removeFromSuperview];
    }
    
    self.uploadProgressView = [[SCRecordingUploadProgressView alloc] initWithFrame:CGRectMake(26, 58, CGRectGetWidth(self.view.bounds) - 52, CGRectGetHeight(self.view.bounds) - 26 - 58)];
    [self.view addSubview:self.uploadProgressView];
    
    [self.uploadProgressView setTitle:self.title];
    [self.uploadProgressView setLocationTitle:self.locationTitle];
    [self.uploadProgressView setCoverImage:self.coverImage];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setObject:self.title forKey:@"track[title]"];
    [parameters setObject:(self.isPrivate) ? @"private" : @"public" forKey:@"track[sharing]"];
    if (self.fileURL) {
        [parameters setObject:self.fileURL forKey:@"track[asset_data]"];
    } else {
        [parameters setObject:self.fileData forKey:@"track[asset_data]"];
    }
    
    [SCRequest performMethod:SCRequestMethodPOST
                  onResource:[NSURL URLWithString:@"https://api.soundcloud.com/tracks.json"]
             usingParameters:parameters
                 withAccount:self.account
      sendingProgressHandler:^(unsigned long long bytesSend, unsigned long long bytesTotal){self.uploadProgressView.progressView.progress = (float)bytesSend / bytesTotal;}
             responseHandler:^(NSURLResponse *response, NSData *data, NSError *error){
                 if (data) {
                     NSError *jsonError = nil;
                     id result = [data objectFromJSONData]; //[NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                     if (result) {
                         
                         [self.uploadProgressView setSuccess:YES];
                         
                         double delayInSeconds = 2.0;
                         dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                         dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                             self.completionHandler(NO, result);
                         });
                     } else {
                         NSLog(@"Upload failed with json error: %@", [jsonError localizedDescription]);
                         
                         [self.uploadProgressView setSuccess:NO];
                         [self.navigationController setToolbarHidden:NO animated:YES];
                         UIBarButtonItem *button = [self.toolbarItems lastObject];
                         button.title = NSLocalizedString(@"retry_upload", @"Retry upload");
                     }
                 } else {
                     NSLog(@"Upload failed with error: %@", [error localizedDescription]);
                     
                     [self.uploadProgressView setSuccess:NO];
                     [self.navigationController setToolbarHidden:NO animated:YES];
                     UIBarButtonItem *button = [self.toolbarItems lastObject];
                     button.title = NSLocalizedString(@"retry_upload", @"Retry upload");
                 }
             }];
    
    [self.uploadProgressView.cancelButton addTarget:self
                                             action:@selector(cancel)
                                   forControlEvents:UIControlEventTouchUpInside];
}

- (IBAction)cancel;
{
    NSLog(@"canceling ...");
    self.completionHandler(YES, nil);
}

- (IBAction)logout;
{
    NSLog(@"Logging out ...");
}

@end


#pragma mark -


@implementation SCRecordingSaveViewControllerTextField

- (void)drawPlaceholderInRect:(CGRect)rect;
{
    [[UIColor colorWithWhite:0.6 alpha:1.0] setFill];
    [self.placeholder drawInRect:rect withFont:self.font];
}

@end

