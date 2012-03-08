//
//  GHDLoginViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDLoginViewController.h"
#import "GHDLoginView.h"
#import "GHGitHubClient.h"
#import "GHJSONRequestOperation.h"
#import "GHUserAccount.h"

@interface GHDLoginViewController ()
@property (nonatomic, assign) BOOL successHidden;
@property (nonatomic, assign) BOOL loginFailedHidden;
@property (nonatomic, assign) BOOL loginEnabled;
@property (nonatomic, assign) BOOL loggingIn;
@property (nonatomic, strong) RACAsyncCommand *loginCommand;
@property (nonatomic, strong) GHDLoginView *view;
@property (nonatomic, strong) GHUserAccount *userAccount;
@property (nonatomic, strong) GHGitHubClient *client;
@end


@implementation GHDLoginViewController

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.loginFailedHidden = YES;
	self.successHidden = YES;
	self.loginEnabled = NO;
	self.loggingIn = NO;
	
	self.loginCommand = [RACAsyncCommand command];
	
	[[RACSequence 
		combineLatest:[NSArray arrayWithObjects:RACObservable(self.username), RACObservable(self.password), self.loginCommand.canExecuteValue, nil] 
		reduce:^(NSArray *xs) { return [NSNumber numberWithBool:[[xs objectAtIndex:0] length] > 0 && [[xs objectAtIndex:1] length] > 0 && [[xs objectAtIndex:2] boolValue]]; }]
		toObject:self keyPath:RACKVO(self.loginEnabled)];
	
	[self.loginCommand subscribeNext:^(id _) {
		self.userAccount = [GHUserAccount userAccountWithUsername:self.username password:self.password];
		self.client = [GHGitHubClient clientForUserAccount:self.userAccount];
	}];
	
	RACValue *loginResult = [self.loginCommand addOperationBlock:^{
		return [self.client operationWithMethod:@"GET" path:@"" parameters:nil];
	}];
	
	[loginResult subscribeNext:^(id _) {
		self.successHidden = NO;
		self.loginFailedHidden = YES; 
	} error:^(NSError *error) {
		self.successHidden = YES;
		self.loginFailedHidden = NO;
	}];
	
	RACAsyncCommand *getUserInfo = [RACAsyncCommand command];
	RACValue *getUserInfoResult = [getUserInfo addOperationBlock:^{
		return [self.client operationWithMethod:@"GET" path:@"user" parameters:nil];
	}];
	
	[[[loginResult 
		doNext:^(id x) { [getUserInfo execute:x]; }] 
		selectMany:^(id _) { return getUserInfoResult; }] 
		subscribeNext:^(id x) { NSLog(@"%@", x); }
		error:^(NSError *error) { NSLog(@"error: %@", error); }];
	
	[[[[[self.loginCommand 
		doNext:^(id _) { self.loggingIn = YES; }]
		selectMany:^(id _) { return loginResult; }] 
		selectMany:^(id _) { return getUserInfoResult; }]
		doError:^(NSError *_) { self.loggingIn = NO; }]
		subscribeNext:^(id _) { self.loggingIn = NO; }];

	[[RACSequence 
		merge:[NSArray arrayWithObjects:RACObservable(self.username), RACObservable(self.password), nil]] 
		subscribeNext:^(id _) { self.successHidden = self.loginFailedHidden = YES; }];
	
	return self;
}


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView view];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.username)];
	[self.view.passwordTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.password)];
	[self.view.successTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.successHidden)];
	[self.view.couldNotLoginTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.loginFailedHidden)];
	[self.view.loginButton bind:NSEnabledBinding toObject:self withKeyPath:RACKVO(self.loginEnabled)];
	[self.view.loggingInSpinner bind:NSHiddenBinding toObject:self withNegatedKeyPath:RACKVO(self.loggingIn)];
	
	[self.view.loggingInSpinner startAnimation:nil];
	
	[self.view.loginButton addCommand:self.loginCommand];
}


#pragma mark API

@synthesize username;
@synthesize password;
@dynamic view;
@synthesize successHidden;
@synthesize loginFailedHidden;
@synthesize loginCommand;
@synthesize loginEnabled;
@synthesize loggingIn;
@synthesize userAccount;
@synthesize client;

@end