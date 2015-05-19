//
//  IAPHelper.m
//
//  Original Created by Ray Wenderlich on 2/28/11.
//  Created by saturngod on 7/9/12.
//  Copyright 2011 Ray Wenderlich. All rights reserved.
//

#import "IAPHelper.h"
#import "NSString+Base64.h"
#import "SFHFKeychainUtils.h"

#if ! __has_feature(objc_arc)
#error You need to either convert your project to ARC or add the -fobjc-arc compiler flag to IAPHelper.m.
#endif


@interface IAPHelper()
@property (nonatomic,copy) IAPProductsResponseBlock requestProductsBlock;
@property (nonatomic,copy) IAPBuyProductCompleteResponseBlock buyProductCompleteBlock;
@property (nonatomic,copy) IAPRestoreProductsCompleteResponseBlock restoreCompletedBlock;
@property (nonatomic,copy) IAPVerifyReceiptCompleteResponseBlock verifyReceiptCompleteBlock;

@property (nonatomic,strong) NSMutableData* receiptRequestData;
@end

@implementation IAPHelper

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static id sharedInstance;
    
    dispatch_once(&once, ^{
        sharedInstance = [self new];
    });
    
    return sharedInstance;
}

- (void)iapWithProductIdentifiers:(NSSet *)productIdentifiers {
    // Store product identifiers
    _productIdentifiers = productIdentifiers;
    
    // Check for previously purchased products
    NSMutableSet * purchasedProducts = [NSMutableSet set];
    for (NSString * productIdentifier in _productIdentifiers) {
        NSString* password = [SFHFKeychainUtils getPasswordForUsername:productIdentifier andServiceName:@"IAPHelper" error:nil];
        BOOL productPurchased = [password isEqualToString:@"YES"];
        
        if (productPurchased) {
            [purchasedProducts addObject:productIdentifier];
            
        }
    }
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    self.purchasedProducts = purchasedProducts;
}

-(BOOL)isPurchasedProductIdentifier:(NSString*)productIdentifier
{
    NSString* password = [SFHFKeychainUtils getPasswordForUsername:productIdentifier andServiceName:@"IAPHelper" error:nil];
    return [password isEqualToString:@"YES"];
}

- (void)requestProductsWithCompletion:(IAPProductsResponseBlock)completion {
    self.request = [[SKProductsRequest alloc] initWithProductIdentifiers:_productIdentifiers];
    _request.delegate = self;
    self.requestProductsBlock = completion;
    
    [_request start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    self.products = response.products;
    self.request = nil;

    if(_requestProductsBlock) {
        _requestProductsBlock (request, response);
    }
}

- (void)recordTransaction:(SKPaymentTransaction *)transaction {    
    // TODO: Record the transaction on the server side...    
}

- (void)provideContent:(NSString *)productIdentifier {
    [SFHFKeychainUtils storeUsername:productIdentifier andPassword:@"YES" forServiceName:@"IAPHelper" updateExisting:YES error:nil];
    [_purchasedProducts addObject:productIdentifier];
}

- (void)clearSavedPurchasedProducts {
    for (NSString * productIdentifier in _productIdentifiers) {
        [self clearSavedPurchasedProductByID:productIdentifier];
    }
}
- (void)clearSavedPurchasedProductByID:(NSString*)productIdentifier {
    [SFHFKeychainUtils deleteItemForUsername:productIdentifier andServiceName:@"IAPHelper" error:nil];
    [_purchasedProducts removeObject:productIdentifier];
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    [self recordTransaction: transaction];
    
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    
    if(_buyProductCompleteBlock)
    {
        _buyProductCompleteBlock(transaction);
    }
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    [self recordTransaction: transaction];
    
    if (transaction.originalTransaction)
        [self provideContent: transaction.originalTransaction.payment.productIdentifier];
    else
        [self provideContent: transaction.payment.productIdentifier];

    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];

    if(_buyProductCompleteBlock)
    {
        _buyProductCompleteBlock(transaction);
    }
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    if (transaction.error.code != SKErrorPaymentCancelled)
    {
        NSLog(@"Transaction error: %@ %ld", transaction.error.localizedDescription,(long)transaction.error.code);
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    
    if(_buyProductCompleteBlock) {
        _buyProductCompleteBlock(transaction);
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    }
}

- (void)buyProductIdentifier:(NSString *)productIdentifier onCompletion:(IAPBuyProductCompleteResponseBlock)completion {
    SKProduct *product = nil;
    for (SKProduct *obj in self.products) {
        if ([obj.productIdentifier isEqualToString:productIdentifier]) {
            product = obj;
            break;
        }
    }
    
    [self buyProduct:product onCompletion:completion];
}

- (void)buyProduct:(SKProduct *)product onCompletion:(IAPBuyProductCompleteResponseBlock)completion {
    if (product) {
        [self _buyProduct:product onCompletion:completion];
    } else {
        [self requestProductsWithCompletion:^(SKProductsRequest *request, SKProductsResponse *response) {
            [self _buyProduct:product onCompletion:completion];
        }];
    }
}

- (void)_buyProduct:(SKProduct *)product onCompletion:(IAPBuyProductCompleteResponseBlock)completion {
    self.buyProductCompleteBlock = completion;
    
    self.restoreCompletedBlock = nil;
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

-(void)restoreProductsWithCompletion:(IAPRestoreProductsCompleteResponseBlock)completion {
    //clear it
    self.buyProductCompleteBlock = nil;
    
    self.restoreCompletedBlock = completion;
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSLog(@"Transaction error: %@ %ld", error.localizedDescription,(long)error.code);
    if(_restoreCompletedBlock) {
        _restoreCompletedBlock(queue,error);
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    for (SKPaymentTransaction *transaction in queue.transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStateRestored:
            {
                [self recordTransaction: transaction];
                if (transaction.originalTransaction)
                    [self provideContent: transaction.originalTransaction.payment.productIdentifier];
                else
                    [self provideContent: transaction.payment.productIdentifier];
            }
            default:
                break;
        }
    }
    
    if(_restoreCompletedBlock) {
        _restoreCompletedBlock(queue,nil);
    }
}

- (void)verifyReceipt:(NSData*)receiptData onCompletion:(IAPVerifyReceiptCompleteResponseBlock)completion
{
    [self verifyReceipt:receiptData secretKey:nil onCompletion:completion];
}
- (void)verifyReceipt:(NSData*)receiptData secretKey:(NSString*)secretKey onCompletion:(IAPVerifyReceiptCompleteResponseBlock)completion
{
    self.verifyReceiptCompleteBlock = completion;

    NSError *jsonError = nil;
    NSString *receiptBase64 = [NSString base64StringFromData:receiptData length:[receiptData length]];


    NSData *jsonData = nil;

    if(secretKey !=nil && ![secretKey isEqualToString:@""]) {
        
        jsonData = [NSJSONSerialization dataWithJSONObject:[NSDictionary dictionaryWithObjectsAndKeys:receiptBase64,@"receipt-data",
                                                            secretKey,@"password",
                                                            nil]
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&jsonError];
        
    }
    else {
        jsonData = [NSJSONSerialization dataWithJSONObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                receiptBase64,@"receipt-data",
                                                                nil]
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&jsonError
                        ];
    }


//    NSString* jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    NSURL *requestURL = nil;
    if(_production)
    {
        requestURL = [NSURL URLWithString:@"https://buy.itunes.apple.com/verifyReceipt"];
    }
    else {
        requestURL = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    }

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:requestURL];
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:jsonData];

    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:req delegate:self];
    if(conn) {
        self.receiptRequestData = [[NSMutableData alloc] init];
    } else {
        NSError* error = nil;
        NSMutableDictionary* errorDetail = [[NSMutableDictionary alloc] init];
        [errorDetail setValue:@"Can't create connection" forKey:NSLocalizedDescriptionKey];
        error = [NSError errorWithDomain:@"IAPHelperError" code:100 userInfo:errorDetail];
        if(_verifyReceiptCompleteBlock) {
            _verifyReceiptCompleteBlock(nil,error);
        }
    }
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Cannot transmit receipt data. %@",[error localizedDescription]);
    
    if(_verifyReceiptCompleteBlock) {
        _verifyReceiptCompleteBlock(nil,error);
    }
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.receiptRequestData setLength:0];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.receiptRequestData appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *response = [[NSString alloc] initWithData:self.receiptRequestData encoding:NSUTF8StringEncoding];
    
    if(_verifyReceiptCompleteBlock) {
        _verifyReceiptCompleteBlock(response,nil);
    }
}

- (void)dealloc
{
    //http://stackoverflow.com/questions/4150926/in-app-purchase-crashes-on-skpaymentqueue-defaultqueue-addpaymentpayment
    //https://github.com/saturngod/IAPHelper/issues/9
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}
@end
