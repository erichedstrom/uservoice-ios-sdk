//
//  UVContactViewController.h
//  UserVoice
//
//  Created by Austin Taylor on 10/18/13.
//  Copyright (c) 2013 UserVoice Inc. All rights reserved.
//

#import "UVBaseViewController.h"
#import "UVInstantAnswerManager.h"
#import "UVTextWithFieldsView.h"

@class UVTextView;

@interface UVContactViewController : UVBaseViewController<UVInstantAnswersDelegate, UITextViewDelegate, UIActionSheetDelegate>

@property (nonatomic, retain) UITextField *emailField;
@property (nonatomic, retain) UITextField *firstNameField;
@property (nonatomic, retain) UITextField *lastNameField;
@property (nonatomic, retain) NSString *messageTitle;

@property (nonatomic,retain) UVInstantAnswerManager *instantAnswerManager;
@property (nonatomic,retain) NSString *loadedDraft;

@property(nonatomic, strong) UVTextWithFieldsView *fieldsView;

- (void)doSendContent;
- (void)next;

@end
