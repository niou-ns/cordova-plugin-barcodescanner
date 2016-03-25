//  BarcodeCamera.h
//
//  Created by Krzysztof Pintscher 03/18/16


#import <Cordova/CDV.h>

@interface BarcodeCameraView : UIViewController
{}
+ (instancetype) createView;
@end


@interface BarcodeCamera : CDVPlugin
{}
@property (strong) BarcodeCameraView* barcodeView;
@property (readwrite, assign) BOOL hasPendingOperation;
@property (readwrite) BOOL allowRotate;
@property (readwrite) NSArray* supportedOrientations;

- (void) show:(CDVInvokedUrlCommand *)command;
- (void) close:(CDVInvokedUrlCommand *)command;

@end
