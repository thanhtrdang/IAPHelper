//
//  IAPHelper.h
//
//  Original Created by Ray Wenderlich on 2/28/11.
//  Created by saturngod on 7/9/12.
//  Copyright 2011 Ray Wenderlich. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StoreKit/StoreKit.h"

#define sIAPHelper [IAPHelper sharedInstance]

typedef void (^IAPProductsResponseBlock)(SKProductsRequest* request , SKProductsResponse* response);
typedef void (^IAPBuyProductCompleteResponseBlock)(SKPaymentTransaction* transcation);
typedef void (^IAPVerifyReceiptCompleteResponseBlock)(NSString* response,NSError* error);
typedef void (^IAPRestoreProductsCompleteResponseBlock) (SKPaymentQueue* payment, NSError* error);

@interface IAPHelper : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic,strong) NSSet *productIdentifiers;
@property (nonatomic,strong) NSArray *products;
@property (nonatomic,strong) NSMutableSet *purchasedProducts;
@property (nonatomic,strong) SKProductsRequest *request;
@property (nonatomic) BOOL production;

+ (instancetype)sharedInstance;

- (void)iapWithProductIdentifiers:(NSSet *)productIdentifiers;

- (BOOL)isPurchasedProductIdentifier:(NSString*)productIdentifier;

- (void)requestProductsWithCompletion:(IAPProductsResponseBlock)completion;

- (void)buyProductIdentifier:(NSString *)productIdentifier onCompletion:(IAPBuyProductCompleteResponseBlock)completion;
- (void)buyProduct:(SKProduct *)product onCompletion:(IAPBuyProductCompleteResponseBlock)completion;

- (void)restoreProductsWithCompletion:(IAPRestoreProductsCompleteResponseBlock)completion;

- (void)verifyReceipt:(NSData*)receiptData onCompletion:(IAPVerifyReceiptCompleteResponseBlock)completion;
- (void)verifyReceipt:(NSData*)receiptData secretKey:(NSString*)secretKey onCompletion:(IAPVerifyReceiptCompleteResponseBlock)completion;

- (void)provideContent:(NSString *)productIdentifier;

- (void)clearSavedPurchasedProducts;
- (void)clearSavedPurchasedProductByID:(NSString*)productIdentifier;
@end