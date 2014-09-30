//
//  UVContactViewController.m
//  UserVoice
//
//  Created by Austin Taylor on 10/18/13.
//  Copyright (c) 2013 UserVoice Inc. All rights reserved.
//

#import "UVAccessToken.h"
#import "UVContactViewController.h"
#import "UVInstantAnswersViewController.h"
#import "UVDetailsFormViewController.h"
#import "UVSuccessViewController.h"
#import "UVTextView.h"
#import "UVSession.h"
#import "UVClientConfig.h"
#import "UVConfig.h"
#import "UVTicket.h"
#import "UVCustomField.h"
#import "UVBabayaga.h"
#import "UVTextWithFieldsView.h"

#import "Theme.h"
#import "Utilities.h"
#import "WeddingPerson.h"
#import "UVUser.h"

@implementation UVContactViewController {
    BOOL _proceed;
    BOOL _sending;
}

- (void)loadView {
    UIView *view = [UIView new];
    view.backgroundColor = [UIColor whiteColor];
    view.frame = [self contentFrame];

    [self registerForKeyboardNotifications];
    _instantAnswerManager = [UVInstantAnswerManager new];
    _instantAnswerManager.delegate = self;
    _instantAnswerManager.articleHelpfulPrompt = NSLocalizedStringFromTableInBundle(@"Do you still want to contact us?", @"UserVoice", [UserVoice bundle], nil);
    _instantAnswerManager.articleReturnMessage = NSLocalizedStringFromTableInBundle(@"Yes, go to my message", @"UserVoice", [UserVoice bundle], nil);
    _instantAnswerManager.deflectingType = @"Ticket";

  self.navigationItem.title = NSLocalizedString(@"Your Message", @"Your Message");

    // using a fields view with no fields extra still gives us better scroll handling
    _fieldsView = [UVTextWithFieldsView new];

    _firstNameField = [_fieldsView addFieldWithLabel:NSLocalizedString(@"First Name", @"First Name") ];
    _firstNameField.placeholder = NSLocalizedString(@"Required", @"Required");
    _firstNameField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"uv-user-first-name"]; //self.userName;
  _firstNameField.font = [Theme font];

    _lastNameField= [_fieldsView addFieldWithLabel:NSLocalizedString(@"Last Name", @"Last Name")];
    _lastNameField.placeholder = NSLocalizedString(@"Required", @"Required");
  _lastNameField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"uv-user-last-name"];
    _lastNameField.font = [Theme font];

    _emailField = [_fieldsView addFieldWithLabel:NSLocalizedStringFromTableInBundle(@"Email", @"UserVoice", [UserVoice bundle], nil)];
    _emailField.keyboardType = UIKeyboardTypeEmailAddress;
    _emailField.autocorrectionType = UITextAutocorrectionTypeNo;
    _emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _emailField.placeholder = NSLocalizedString(@"Required", @"Required");
    _emailField.font = [Theme font];
    WeddingPerson *weddingPerson = [Utilities fetchCurrentWeddingPerson];

    // don't populate the email field if it is the default WeddingPerson.id@appuser..
    if (![self.userEmail hasPrefix:weddingPerson.objectId]) {
      _emailField.text = self.userEmail;
    }

//    _fieldsView.textView.placeholder = NSLocalizedStringFromTableInBundle(@"Give feedback or ask for help...", @"UserVoice", [UserVoice bundle], nil);

      _fieldsView.textView.placeholder = NSLocalizedString(@"Your message...", @"Your message...");

  _fieldsView.textView.font = [Theme font];

    _fieldsView.textViewDelegate = self;
    [self configureView:view
               subviews:NSDictionaryOfVariableBindings(_fieldsView)
            constraints:@[@"|[_fieldsView]|", @"V:|[_fieldsView]|"]];

  /*
   self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Cancel", @"UserVoice", [UserVoice bundle], nil)
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(requestDismissal)];
*/

  UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismiss)];

  [cancelButton setTitleTextAttributes:[Theme navigationBarButtonTextAttributes] forState:UIControlStateNormal];

  self.navigationItem.leftBarButtonItem = cancelButton;


  /* self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Next", @"UserVoice", [UserVoice bundle], nil)
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(next)];
   
  */

  UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Send", @"UserVoice", [UserVoice bundle], nil)
                                                                 style:UIBarButtonItemStyleDone
                                                                target:self
                                                                action:@selector(next)];

  [doneButton setTitleTextAttributes:[Theme navigationBarButtonTextAttributes] forState:UIControlStateNormal];

  self.navigationItem.rightBarButtonItem = doneButton;


    [self loadDraft];
    self.navigationItem.rightBarButtonItem.enabled = ([_fieldsView.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length > 0);
    self.view = view;

    [[UVSession currentSession].user enableEmailUpdates:NO delegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
  self.navigationItem.title = NSLocalizedString(@"Your Message", @"Your Message");
    [_fieldsView.textView becomeFirstResponder];
    [super viewWillAppear:animated];
}

- (void)textViewDidChange:(UVTextView *)theTextEditor {
    NSString *text = [theTextEditor.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    self.navigationItem.rightBarButtonItem.enabled = (text.length > 0);
    _instantAnswerManager.searchText = text;
}

- (void)didUpdateInstantAnswers {
    if (_proceed) {
        _proceed = NO;
        [self hideActivityIndicator];
        [_instantAnswerManager pushInstantAnswersViewForParent:self articlesFirst:YES];
    }
}

- (void)next {
   self.navigationItem.title = @"";
    _proceed = YES;
    [self showActivityIndicator];
    [_instantAnswerManager search];
    if (!_instantAnswerManager.loading) {
        [self didUpdateInstantAnswers];
    }
}

- (UIScrollView *)scrollView {
    return _fieldsView;
}

- (void)showActivityIndicator {
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activityView.color = [UVStyleSheet instance].navigationBarActivityIndicatorColor;
    [activityView startAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:activityView];
}

- (void)hideActivityIndicator {
  UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Next", @"UserVoice", [UserVoice bundle], nil) style:UIBarButtonItemStyleDone target:self action:@selector(next)];

  self.navigationItem.rightBarButtonItem = nextButton;

  [nextButton setTitleTextAttributes:[Theme navigationBarButtonTextAttributes] forState:UIControlStateNormal];
}

- (void)skipInstantAnswers {


  if ([self.firstNameField.text length] == 0) {

    UIAlertView *firstNameAlert = [[UIAlertView alloc] initWithTitle:@"Verify First Name" message:@"Please enter your first name." delegate:self
                                               cancelButtonTitle:@"OK" otherButtonTitles:nil];

    [firstNameAlert show];
    return;

  }


  if ([self.lastNameField.text length] == 0) {

    UIAlertView *lastNameAlert = [[UIAlertView alloc] initWithTitle:@"Verify Last Name" message:@"Please enter your last name." delegate:self
                                                   cancelButtonTitle:@"OK" otherButtonTitles:nil];

    [lastNameAlert show];
    return;
    
  }


  [[NSUserDefaults standardUserDefaults] setObject:self.firstNameField.text forKey:@"uv-user-first-name"];
  [[NSUserDefaults standardUserDefaults] setObject:self.lastNameField.text forKey:@"uv-user-last-name"];

  NSString *displayName = [NSString stringWithFormat:@"%@ %@", self.firstNameField.text, self.lastNameField.text];

    [self sendWithEmail:self.emailField.text name:displayName fields:[NSMutableDictionary dictionary]];
/*
    _detailsController = [UVDetailsFormViewController new];
    _detailsController.delegate = self;
    _detailsController.sendTitle = NSLocalizedStringFromTableInBundle(@"Send", @"UserVoice", [UserVoice bundle], nil);
    NSMutableArray *fields = [NSMutableArray array];
    for (UVCustomField *field in [UVSession currentSession].clientConfig.customFields) {
        NSMutableArray *values = [NSMutableArray array];
        if (!field.isRequired && field.isPredefined)
            [values addObject:@{@"id" : @"", @"label" : NSLocalizedStringFromTableInBundle(@"(none)", @"UserVoice", [UserVoice bundle], nil)}];
        for (NSString *value in field.values) {
            [values addObject:@{@"id" : value, @"label" : value}];
        }
        if (field.isRequired)
            [fields addObject:@{ @"name" : field.name, @"values" : values, @"required" : @(1) }];
        else
            [fields addObject:@{ @"name" : field.name, @"values" : values }];
    }
    _detailsController.fields = fields;
    _detailsController.selectedFieldValues = [NSMutableDictionary dictionary];
    for (NSString *key in [UVSession currentSession].config.customFields.allKeys) {
        NSString *value = [UVSession currentSession].config.customFields[key];
        _detailsController.selectedFieldValues[key] = @{ @"id" : value, @"label" : value };
    }
    [self.navigationController pushViewController:_detailsController animated:YES];
 */
}

- (BOOL)validateCustomFields:(NSDictionary *)fields {
    for (UVCustomField *field in [UVSession currentSession].clientConfig.customFields) {
        if ([field isRequired]) {
            NSString *value = fields[field.name];
            if (!value || value.length == 0)
                return NO;
        }
    }
    return YES;
}

// send message contents as new UserVoice ticket
// this method can be overridden to send via other channels, e.g. see MessageReplyViewController
- (void)doSendContent {

  NSMutableDictionary *customFields = [NSMutableDictionary dictionary];

  [UVTicket createWithMessage:_fieldsView.textView.text andEmailIfNotLoggedIn:self.userEmail andName:self.userName andTitle:self.title andCustomFields:customFields andDelegate:self];
}

- (void)sendWithEmail:(NSString *)email name:(NSString *)name fields:(NSDictionary *)fields {
    if (_sending) return;

    NSMutableDictionary *userUpdates = [NSMutableDictionary dictionary];
    BOOL changedEmail = NO;

    if ([Utilities isValidEmailAddress:email] && ![email isEqualToString:self.userEmail]) {
      self.userEmail = email;
      changedEmail = YES;
    }
    WeddingPerson *weddingPerson = [Utilities fetchCurrentWeddingPerson];
    if ([self.userEmail length] == 0 || [self.userEmail hasPrefix:weddingPerson.objectId]) {

      UIAlertView *emailAlert = [[UIAlertView alloc] initWithTitle:@"Verify Email" message:@"Please enter a valid email address." delegate:self
                                                 cancelButtonTitle:@"OK" otherButtonTitles:nil];

      [emailAlert show];
      return;

    }

    if (![self.userName isEqualToString:name]) {
      self.userName = name;
      userUpdates[@"display_name"] = name;
    }

    [self showActivityIndicator];

    // if we have a new name or email for the user, update the user in UserVoice
    if ([userUpdates count] > 0 && !changedEmail) {
      [[UVSession currentSession].user updateProperties:userUpdates delegate:self];
    }

    // send the ticket
    _sending = YES;
  [self doSendContent];
}

- (void)didCreateTicket:(UVTicket *)ticket {
    [self clearDraft];
    [UVBabayaga track:SUBMIT_TICKET];
    UVSuccessViewController *next = [UVSuccessViewController new];
    next.titleText = NSLocalizedString(@"Thank you!", @"Thank you!");

    next.text = NSLocalizedString(@"Your message has been sent.\n\nWe review our messages regularly. If your request needs a reply, you will find that in your Inbox on the Home screen.", @"Your message has been sent.\n\nWe review our messages regularly. If your request needs a reply, you will find that in your Inbox on the Home screen.");
    [self.navigationController setViewControllers:@[next] animated:YES];
}

- (void)didUpdateUser:(UVUser *)user {
  
}

- (void)didReceiveError:(NSError *)error {
    _sending = NO;
    [self hideActivityIndicator];
    // [_detailsController hideActivityIndicator];
    [super didReceiveError:error];
}

- (void)showSaveActionSheet {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedStringFromTableInBundle(@"Cancel", @"UserVoice", [UserVoice bundle], nil)
                                               destructiveButtonTitle:NSLocalizedStringFromTableInBundle(@"Don't save", @"UserVoice", [UserVoice bundle], nil)
                                                    otherButtonTitles:NSLocalizedStringFromTableInBundle(@"Save draft", @"UserVoice", [UserVoice bundle], nil), nil];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [actionSheet showFromBarButtonItem:self.navigationItem.leftBarButtonItem animated:YES];
    } else {
        [actionSheet showInView:self.view];
    }
    [_fieldsView.textView resignFirstResponder];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
            [self clearDraft];
            [self dismiss];
            break;
        case 1:
            [self saveDraft];
            [self dismiss];
            break;
        default:
            [_fieldsView.textView becomeFirstResponder];
            break;
    }
}

- (void)clearDraft {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs removeObjectForKey:@"uv-message-text"];
    [prefs synchronize];
}

- (void)loadDraft {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.loadedDraft = _instantAnswerManager.searchText = _fieldsView.textView.text = [prefs stringForKey:@"uv-message-text"];
}

- (void)saveDraft {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:_fieldsView.textView.text forKey:@"uv-message-text"];
    [prefs synchronize];
}

- (void)requestDismissal {
    if (_fieldsView.textView.text.length == 0 || [_fieldsView.textView.text isEqualToString:_loadedDraft]) {
        [self dismiss];
    } else {
        [self showSaveActionSheet];
    }
}

@end
