//
//  UVContactViewController.m
//  UserVoice
//
//  Created by Austin Taylor on 10/18/13.
//  Copyright (c) 2013 UserVoice Inc. All rights reserved.
//

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
    _nameField = [_fieldsView addFieldWithLabel:NSLocalizedStringFromTableInBundle(@"Name", @"UserVoice", [UserVoice bundle], nil)];

    _nameField.text = self.userName;

    _emailField = [_fieldsView addFieldWithLabel:NSLocalizedStringFromTableInBundle(@"Email", @"UserVoice", [UserVoice bundle], nil)];
    _emailField.keyboardType = UIKeyboardTypeEmailAddress;
    _emailField.autocorrectionType = UITextAutocorrectionTypeNo;
    _emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _emailField.placeholder = NSLocalizedString(@"Optional", @"Optional");
    WeddingPerson *weddingPerson = [Utilities fetchCurrentWeddingPerson];

    // don't populate the email field if it is the default WeddingPerson.id@appuser..
    if (![self.userEmail hasPrefix:weddingPerson.objectId]) {
      _emailField.text = self.userEmail;
    }

//    _fieldsView.textView.placeholder = NSLocalizedStringFromTableInBundle(@"Give feedback or ask for help...", @"UserVoice", [UserVoice bundle], nil);

      _fieldsView.textView.placeholder = NSLocalizedString(@"Your message...", @"Your message...");

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
    [self sendWithEmail:self.emailField.text name:self.nameField.text fields:[NSMutableDictionary dictionary]];
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

  [UVTicket createWithMessage:_fieldsView.textView.text andEmailIfNotLoggedIn:self.userEmail andName:self.userName andCustomFields:customFields andDelegate:self];
}

- (void)sendWithEmail:(NSString *)email name:(NSString *)name fields:(NSDictionary *)fields {
    if (_sending) return;

    NSMutableDictionary *userUpdates = [NSMutableDictionary dictionary];

    if ([Utilities isValidEmailAddress:email] && ![email isEqualToString:self.userEmail]) {
      userUpdates[@"email"] = email;
      self.userEmail = email;
    }
    if ([self.userEmail length] == 0) {
      WeddingPerson *person = [Utilities fetchCurrentWeddingPerson];
      self.userEmail = [person.objectId stringByAppendingString:@"@appuser.weddinghappy.com"];
    }

    if (![self.userName isEqualToString:name]) {
      self.userName = name;
      userUpdates[@"display_name"] = name;
    }

    [self showActivityIndicator];

    // if we have a new name or email for the user, update the user in UserVoice
    if ([userUpdates count] > 0) {
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
    next.titleText = NSLocalizedStringFromTableInBundle(@"Thank you!", @"UserVoice", [UserVoice bundle], nil);
    next.text = NSLocalizedStringFromTableInBundle(@"Your message has been sent.\n\nWe will send our reply to your Inbox (that's on the Home screen) if your message requires a response.\n\nPlease expect a response within 48 hours.", @"UserVoice", [UserVoice bundle], nil);
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
