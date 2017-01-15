//
//  ViewController.m
//  BonusCalc
//
//  Created by Newman, Scott on 5/6/16.
//  Copyright © 2016 Scott Newman. All rights reserved.
//

#import "ViewController.h"

#import <SVProgressHUD/SVProgressHUD.h>
#import <TRCurrencyTextField/TRCurrencyTextField.h>
#import <TRCurrencyTextField/TRFormatterHelper.h>
#import <TRCurrencyTextField/TRLocaleHelper.h>

@interface ViewController () <NSURLSessionDelegate, NSURLSessionTaskDelegate>

@property (weak, nonatomic) IBOutlet TRCurrencyTextField *stockPriceField;
@property (weak, nonatomic) IBOutlet UIButton *fetchButton;
@property (weak, nonatomic) IBOutlet UILabel *lastUpdatedLabel;
@property (weak, nonatomic) IBOutlet UILabel *grossValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalTaxesLabel;
@property (weak, nonatomic) IBOutlet UILabel *netValueLabel;
@property (strong, nonatomic) NSMutableData *stockFetchData;
@property (strong, nonatomic) NSMutableURLRequest *stockFetchRequest;
@property (strong, nonatomic) NSURLSessionTask *stockFetchTask;
@property (strong, nonatomic) NSURLSession *dataSession;

@end

@implementation ViewController

const int numberOfVestingShares = 29;

- (void)viewDidLoad {
    [super viewDidLoad];

    // Configure HUD
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeBlack];
    
    // Configure stock price field
    [self.stockPriceField setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [self.stockPriceField setClearButtonMode:UITextFieldViewModeNever];
    [self.stockPriceField setMaxDigits:6];
    
    // Configure session & request data
    self.stockFetchData = [NSMutableData data];
    
    self.dataSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    
    self.stockFetchRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com/finance/info?client=ig&q=AMZN"]];
    [self.stockFetchRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [self.stockFetchRequest addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    // Configure keyboard accessory view
    UIToolbar *keyboardDoneButtonView = [[UIToolbar alloc] init];
    [keyboardDoneButtonView sizeToFit];
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Calculate" style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonTapped:)];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [keyboardDoneButtonView setItems:[NSArray arrayWithObjects:flexSpace, doneButton, nil]];
    
    self.stockPriceField.inputAccessoryView = keyboardDoneButtonView;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self resetFetchState:YES UIState:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)fetchButtonTapped:(id)sender {
    [self.stockFetchData setData:[NSData data]];
    [self.stockPriceField resignFirstResponder];
    
    [SVProgressHUD show];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.stockFetchTask = [self.dataSession dataTaskWithRequest:self.stockFetchRequest];
        [self.stockFetchTask resume];
    });
}

- (void)doneButtonTapped:(id)sender {
    [self.stockPriceField resignFirstResponder];
    
    [self calculateTotals];
}

- (void)resetFetchState:(BOOL)resetFetchState UIState:(BOOL)resetUIState {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD dismiss];
        
        if (resetFetchState) {
            [self.stockFetchData setData:[NSData data]];
            [self.stockFetchTask cancel];
        }
        
        if (resetUIState) {
            self.lastUpdatedLabel.text = @"";
            self.stockPriceField.value = [NSNumber numberWithInt:0];
            self.grossValueLabel.text = @"$0.00";
            self.totalTaxesLabel.text = @"0.00";
            self.netValueLabel.text = @"$0.00";
        }
    });
}

- (void)calculateTotals {
    double stockPrice = [self.stockPriceField.value doubleValue];
    
    // Calculate total value
    double grossValue = (stockPrice * numberOfVestingShares);
    self.grossValueLabel.text = [NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithDouble:grossValue] numberStyle:NSNumberFormatterCurrencyStyle];
    
    // Calculate total taxes
    double totalTaxes = ((grossValue * 0.25) + (grossValue * 0.062) + (grossValue * 0.0145) + (grossValue * 0.0307) + (grossValue * 0.011995) + 12.22);
    self.totalTaxesLabel.text = [NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithDouble:totalTaxes] numberStyle:NSNumberFormatterCurrencyStyle];
    
    // Calculate net value
    double netValue = (grossValue - totalTaxes);
    self.netValueLabel.text = [NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithDouble:netValue] numberStyle:NSNumberFormatterCurrencyStyle];
}

- (IBAction)stockPriceEditingDidBegin:(id)sender {
    [self resetFetchState:YES UIState:YES];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.stockFetchData appendData:data];
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    NSError *jsonError = nil;

    NSString *responseString = [[NSString alloc] initWithData:self.stockFetchData encoding:NSUTF8StringEncoding];
    responseString = [responseString stringByReplacingOccurrencesOfString:@"// " withString:@""];

    id response = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&jsonError];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (jsonError) {
            [self resetFetchState:YES UIState:NO];
            
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:@"An unexpected error has occured. Please try again later." preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:nil];
            
            [errorAlert addAction:okAction];
            
            [self presentViewController:errorAlert animated:YES completion:nil];
        } else {
            NSDictionary *responseDictionary = response[0];

            self.lastUpdatedLabel.text = [NSString stringWithFormat:@"As of: %@", responseDictionary[@"lt"]];
            self.stockPriceField.value = [NSNumber numberWithDouble:[responseDictionary[@"l_cur"] doubleValue]];
            [self.stockPriceField resignFirstResponder];
            
            [self resetFetchState:YES UIState:NO];
            
            [self calculateTotals];
        }
    });
}

@end
