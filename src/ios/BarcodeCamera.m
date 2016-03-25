//  BarcodeCamera.m
//
//  Created by Krzysztof Pintscher 03/18/2016
//
//
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import "BarcodeCamera.h"

// ===================== //
@interface BarcodeCameraView () <AVCaptureMetadataOutputObjectsDelegate>
{
    AVCaptureSession *_session;
    AVCaptureDevice *_device;
    AVCaptureDeviceInput *_input;
    AVCaptureMetadataOutput *_output;
    AVCaptureVideoPreviewLayer *_prevLayer;

    UIView *_laserBar;
    UINavigationBar *_navbar;
    UILabel *_label;
    UIView *_scanBox;

    BOOL vibrate;
    BOOL beep;

    SystemSoundID _beepSound;
}

@property (strong) BarcodeCamera* barcodeCamera;
@property (strong) NSMutableArray* detectedBarcodes;
@property (copy) NSString* callbackId;

@end;


// ===================== //
@implementation BarcodeCamera

@synthesize hasPendingOperation;

- (void) show:(CDVInvokedUrlCommand *)command
{
    if (self.hasPendingOperation) {
        return;
    }
    self.hasPendingOperation = YES;

    __weak BarcodeCamera* weakSelf = self;

    self.supportedOrientations = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UISupportedInterfaceOrientations"];

    if ([self.supportedOrientations count] > 1) {
        self.allowRotate = YES;
    } else {
        self.allowRotate = NO;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        BarcodeCameraView* barcodeView = [BarcodeCameraView createView];
        weakSelf.barcodeView = barcodeView;
        barcodeView.callbackId = command.callbackId;
        barcodeView.barcodeCamera = weakSelf;
        [weakSelf.viewController presentViewController:weakSelf.barcodeView animated:YES completion:nil];
    });
}

- (void) close:(CDVInvokedUrlCommand *) command
{
    __weak BarcodeCamera* weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[weakSelf.barcodeView presentingViewController] dismissViewControllerAnimated:YES completion:nil];
        weakSelf.hasPendingOperation = NO;
    });
}

@end

// ===================== //
@implementation BarcodeCameraView

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (UIViewController*)childViewControllerForStatusBarHidden
{
    return nil;
}

- (BOOL) shouldAutorotate
{
    return self.barcodeCamera.allowRotate;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (
        [self.barcodeCamera.supportedOrientations containsObject:@"UIInterfaceOrientationPortrait"] &&
        [self.barcodeCamera.supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeLeft"] &&
        [self.barcodeCamera.supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeRight"]
        )
    {
        return UIInterfaceOrientationMaskPortrait|UIInterfaceOrientationMaskLandscapeLeft|UIInterfaceOrientationMaskLandscapeRight;
    } else if (
       [self.barcodeCamera.supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeLeft"] &&
       [self.barcodeCamera.supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeRight"]
        )
    {
        return UIInterfaceOrientationMaskLandscapeLeft|UIInterfaceOrientationMaskLandscapeRight;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    SEL sel = NSSelectorFromString(@"setNeedsStatusBarAppearanceUpdate");
    if ([self respondsToSelector:sel]) {
        [self performSelector:sel withObject:nil afterDelay:0];
    }

    /** Load settings **/
    NSUserDefaults *userSettings = [NSUserDefaults standardUserDefaults];

    id _vibrate = [userSettings objectForKey:@"vibrate"];
    id _beep = [userSettings objectForKey:@"beep_sound"];

    if (_vibrate == nil) {
        NSDictionary *userDefaultsDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithBool:YES], @"vibrate",
                                              nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:userDefaultsDefaults];
    }
    if (_beep == nil) {
        NSDictionary *userDefaultsDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithBool:YES], @"beep_sound",
                                              nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:userDefaultsDefaults];
    }

    vibrate = [userSettings boolForKey:@"vibrate"];
    beep = [userSettings boolForKey:@"beep_sound"];

    [_session startRunning];

    [super viewWillAppear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.autoresizesSubviews = TRUE;
    //self.view.autoresizingMask = TRUE;

    NSString *beepPath = [[NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"BarcodeCamera" withExtension:@"bundle"]] pathForResource:@"beep" ofType:@"m4a"];
    NSURL *beepUrl = [NSURL fileURLWithPath:beepPath];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)beepUrl, &_beepSound);

    _navbar = [[UINavigationBar alloc] init];
    [_navbar setFrame:CGRectMake(0, 0, self.view.bounds.size.width, 64)];

    UINavigationItem *navItem = [[UINavigationItem alloc] init];
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleDone target:self action:@selector(closeView:)];
    leftButton.tintColor = [UIColor whiteColor];
    navItem.leftBarButtonItem = leftButton;

    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Flash" style:UIBarButtonItemStyleDone target:self action:@selector(torchButton:)];
    rightButton.tintColor = [UIColor whiteColor];
    navItem.rightBarButtonItem = rightButton;

    _navbar.items = @[ navItem ];
    _navbar.barTintColor = [UIColor colorWithRed:0.00 green:0.19 blue:0.41 alpha:1.0];
    _navbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // Indicates recognized barcode
    _laserBar = [[UIView alloc] init];
    _laserBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
    _laserBar.layer.borderColor = [UIColor colorWithRed:0.29 green:0.71 blue:0.44 alpha:1.0].CGColor;
    _laserBar.layer.borderWidth = 3;

    // Scanbox - focus barcodes here
    _scanBox = [[UIView alloc] initWithFrame:CGRectMake(20, self.view.bounds.size.height / 2 - self.view.bounds.size.height / 8, self.view.bounds.size.width - 40, self.view.bounds.size.height / 4)];
    _scanBox.layer.borderColor = [UIColor colorWithRed:0.32 green:0.63 blue:0.94 alpha:0.5].CGColor;
    _scanBox.layer.borderWidth = 2;
    _scanBox.layer.cornerRadius = 5;
    _scanBox.layer.masksToBounds = YES;
    _scanBox.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
                                UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

    // Detected barcode string
    _label = [[UILabel alloc] init];
    _label.frame = CGRectMake(0, self.view.bounds.size.height - 40, self.view.bounds.size.width, 40);
    _label.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleWidth;
    _label.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _label.textColor = [UIColor whiteColor];
    _label.textAlignment = NSTextAlignmentCenter;
    _label.text = @"(none)";

    _session = [[AVCaptureSession alloc] init];
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;

    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
    if (_input) {
        [_session addInput:_input];
    } else {
        NSLog(@"Error: %@", error);
    }

    _output = [[AVCaptureMetadataOutput alloc] init];
    [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [_session addOutput:_output];

    _output.metadataObjectTypes = [_output availableMetadataObjectTypes];

    _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _prevLayer.frame = self.view.bounds;
    _prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_prevLayer.connection setVideoOrientation:[self avOrientationForDeviceOrientation:[[UIDevice currentDevice] orientation]]];

    [self.view.layer addSublayer:_prevLayer];

    [self.view addSubview:_laserBar];
    [self.view addSubview:_label];
    [self.view addSubview:_navbar];
    [self.view addSubview:_scanBox];

    [self.view bringSubviewToFront:_laserBar];
    [self.view bringSubviewToFront:_label];
    [self.view bringSubviewToFront:_navbar];
    [self.view bringSubviewToFront:_scanBox];
}

- (void)viewWillDisappear:(BOOL)animated
{
    AVCaptureDevice *flashLight = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([flashLight isTorchAvailable] && [flashLight isTorchModeSupported:AVCaptureTorchModeOn])
    {
        BOOL success = [flashLight lockForConfiguration:nil];
        if (success)
        {
            if ([flashLight isTorchActive]) {
                [flashLight setTorchMode:AVCaptureTorchModeOff];
            }
        }
    }

    [_session stopRunning];
    self.barcodeCamera.hasPendingOperation = NO;
}

- (void)viewDidDisappear:(BOOL)animated
{
    // Make sure the webView will have full size (small issue with iPad rotating)
    [self.barcodeCamera.webView setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [_prevLayer setFrame:CGRectMake(0, 0, size.width, size.height)];
    [_prevLayer.connection setVideoOrientation:[self avOrientationForDeviceOrientation:[[UIDevice currentDevice] orientation]]];

    // Make sure the webView will have full size (small issue with iPad rotating)
    [self.barcodeCamera.webView setFrame:CGRectMake(0, 0, size.width, size.height)];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{

    CGRect highlightViewRect = CGRectZero;
    AVMetadataMachineReadableCodeObject *barCodeObject;
    NSString *detectionString = nil;
    NSArray *barCodeTypes = @[AVMetadataObjectTypeUPCECode, AVMetadataObjectTypeCode39Code, AVMetadataObjectTypeCode39Mod43Code,
                              AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode93Code, AVMetadataObjectTypeCode128Code,
                              AVMetadataObjectTypePDF417Code, AVMetadataObjectTypeQRCode, AVMetadataObjectTypeAztecCode];

    for (AVMetadataObject *metadata in metadataObjects) {
        for (NSString *type in barCodeTypes) {
            if ([metadata.type isEqualToString:type])
            {
                barCodeObject = (AVMetadataMachineReadableCodeObject *)[_prevLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject *)metadata];
                highlightViewRect = barCodeObject.bounds;
                detectionString = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
                break;
            }
        }

        if (detectionString != nil)
        {
            if(![self.detectedBarcodes containsObject:detectionString]) {
                // Add barcode to the barcodes array
                [self.detectedBarcodes addObject:detectionString];

                // Send last scanned barcode to the app
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:detectionString];
                [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
                [self.barcodeCamera.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];

                // Play sound and vibrate
                if (beep) {
                    AudioServicesPlaySystemSound(_beepSound);
                }
                if (vibrate) {
                    AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
                }
                _label.text = detectionString;
                break;
            }
        }
        else {
            _label.text = @"(none)";
        }
    }

    _laserBar.frame = highlightViewRect;
}

//translate the orientation
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation {

    // Default
    AVCaptureVideoOrientation result = AVCaptureVideoOrientationPortrait;

    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft ) {
        result = AVCaptureVideoOrientationLandscapeRight;
    }
    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight ) {
        result = AVCaptureVideoOrientationLandscapeLeft;
    }
    else if( deviceOrientation == UIDeviceOrientationPortrait) {
        result = AVCaptureVideoOrientationPortrait;
    }
    else if( deviceOrientation == UIDeviceOrientationPortraitUpsideDown) {
        result = AVCaptureVideoOrientationPortraitUpsideDown;
    }

    return result;
}

- (void)torchButton:(UIButton*)sender
{
    AVCaptureDevice *flashLight = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([flashLight isTorchAvailable] && [flashLight isTorchModeSupported:AVCaptureTorchModeOn])
    {
        BOOL success = [flashLight lockForConfiguration:nil];
        if (success)
        {
            if ([flashLight isTorchActive]) {
                [flashLight setTorchMode:AVCaptureTorchModeOff];
            } else {
                [flashLight setTorchMode:AVCaptureTorchModeOn];
            }
            [flashLight unlockForConfiguration];
        }
    }
}

- (void)closeView:(UIButton*)sender
{
    CDVPluginResult* pluginResult;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:self.detectedBarcodes];
    [self.barcodeCamera.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];

    [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}

+ (instancetype) createView
{
    BarcodeCameraView* barcodeView = [[BarcodeCameraView alloc] init];
    barcodeView.detectedBarcodes = [[NSMutableArray alloc] init];
    return barcodeView;
}

@end
