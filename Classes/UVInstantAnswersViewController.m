//
//  UVInstantAnswersViewController.m
//  UserVoice
//
//  Created by Austin Taylor on 10/18/13.
//  Copyright (c) 2013 UserVoice Inc. All rights reserved.
//

#import "UVInstantAnswersViewController.h"
#import "UVArticle.h"
#import "UVSuggestion.h"
#import "UVDeflection.h"
#import "Theme.h"

@implementation UVInstantAnswersViewController

#pragma mark ===== Basic View Methods =====

-(void) viewDidLoad {
  [super viewDidLoad];
  // make line go all the way over to the left
  [_tableView setSeparatorInset:UIEdgeInsetsZero];
  [self.tableView setSeparatorInset:UIEdgeInsetsZero];


}

-(void) viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  self.view.backgroundColor = [Theme viewBackground];
  _tableView.backgroundColor = [Theme viewBackground];
}

- (void)loadView {
    [self setupGroupedTableView];
    self.navigationItem.title = NSLocalizedStringFromTableInBundle(@"Are any of these helpful?", @"UserVoice", [UserVoice bundle], nil);

  UIBarButtonItem *noButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"No", @"No")
                                                               style:UIBarButtonItemStyleDone
                                                              target:self
                                                              action:@selector(next)];

  [noButton setTitleTextAttributes:[Theme navigationBarButtonTextAttributes] forState:UIControlStateNormal];

  self.navigationItem.rightBarButtonItem = noButton;

  [Theme styleNavigationBar:self.navigationController.navigationBar];


    NSArray *visibleIdeas = [_instantAnswerManager.ideas subarrayWithRange:NSMakeRange(0, MIN(3, _instantAnswerManager.ideas.count))];
    NSArray *visibleArticles = [_instantAnswerManager.articles subarrayWithRange:NSMakeRange(0, MIN(3, _instantAnswerManager.articles.count))];
    [UVDeflection trackSearchDeflection:[visibleIdeas arrayByAddingObjectsFromArray:visibleArticles] deflectingType:_deflectingType];
}

#pragma mark ===== UITableViewDataSource Methods =====

- (NSInteger)numberOfSectionsInTableView:(UITableView *)theTableView {
    return (_instantAnswerManager.ideas.count > 0 && _instantAnswerManager.articles.count > 0) ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)theTableView numberOfRowsInSection:(NSInteger)section {
    return MIN([self resultsForSection:section].count, 3);
}

- (UITableViewCell *)tableView:(UITableView *)theTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [self sectionIsArticles:indexPath.section] ? @"Article" : @"Suggestion";
    return [self createCellForIdentifier:identifier tableView:theTableView indexPath:indexPath style:UITableViewCellStyleSubtitle selectable:YES];
}

// hackery to avoid upper-case table header label
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
  if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
    UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
    tableViewHeaderFooterView.textLabel.text = [self tableView:tableView titleForHeaderInSection:section];
  }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self sectionIsArticles:section] ? NSLocalizedString(@"Related articles", @"Related articles") : NSLocalizedStringFromTableInBundle(@"Related feedback", @"UserVoice", [UserVoice bundle], nil);
}

- (void)tableView:(UITableView *)theTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:nil action:nil];
    id model = [[self resultsForSection:indexPath.section] objectAtIndex:indexPath.row];
    [_instantAnswerManager pushViewFor:model parent:self];
    [theTableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)initCellForArticle:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
    [_instantAnswerManager initCellForArticle:cell finalCondition:indexPath == nil];
}

- (void)customizeCellForArticle:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
    UVArticle *article = (UVArticle *)[[self resultsForSection:indexPath.section] objectAtIndex:indexPath.row];
    [_instantAnswerManager customizeCell:cell forArticle:article];
}

- (void)initCellForSuggestion:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
    [_instantAnswerManager initCellForSuggestion:cell finalCondition:indexPath == nil];
}

- (void)customizeCellForSuggestion:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
    UVSuggestion *suggestion = (UVSuggestion *)[[self resultsForSection:indexPath.section] objectAtIndex:indexPath.row];
    [_instantAnswerManager customizeCell:cell forSuggestion:suggestion];
}

- (CGFloat)tableView:(UITableView *)theTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self sectionIsArticles:indexPath.section]) {
        return [self heightForDynamicRowWithReuseIdentifier:@"Article" indexPath:indexPath];
    } else {
        return [self heightForDynamicRowWithReuseIdentifier:@"Suggestion" indexPath:indexPath];
    }
}

#pragma mark ===== Misc =====

- (void)next {
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Back", @"UserVoice", [UserVoice bundle], nil) style:UIBarButtonItemStylePlain target:nil action:nil];
    [_instantAnswerManager skipInstantAnswers];
}

- (NSArray *)resultsForSection:(NSInteger)section {
    return [self sectionIsArticles:section] ? _instantAnswerManager.articles : _instantAnswerManager.ideas;
}

- (BOOL)sectionIsArticles:(NSInteger)section {
    return (_articlesFirst && _instantAnswerManager.articles.count > 0) ? section == 0 : section == 1;
}

@end
