/****************************************************************************
 Author: Luma (stubma@gmail.com)
 
 https://github.com/stubma/cocos2dx-better
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 ****************************************************************************/
#if CC_TARGET_PLATFORM == CC_PLATFORM_IOS

#import "CCUtils.h"
#import <StoreKit/StoreKit.h>
#import "EAGLView.h"
#include "CCLocale.h"
#include <sys/sysctl.h>
#import <MediaPlayer/MediaPlayer.h>

// built-in strings
#define S_CANCEL_EN "Cancel"
#define S_CANCEL_ZH "取消"
#define S_OK_EN "OK"
#define S_OK_ZH "确定"

#pragma mark -
#pragma mark delegate of system dialog

@interface CCSystemConfirmDialogDelegate : NSObject <UIAlertViewDelegate> {
@private
	CCCallFunc* m_onOK;
	CCCallFunc* m_onCancel;
}

- (id)initWithOK:(CCCallFunc*)onOK cancel:(CCCallFunc*)onCancel;

@end

@implementation CCSystemConfirmDialogDelegate

- (id)initWithOK:(CCCallFunc*)onOK cancel:(CCCallFunc*)onCancel {
	if(self = [super init]) {
		m_onOK = onOK;
		m_onCancel = onCancel;
        CC_SAFE_RETAIN(m_onOK);
        CC_SAFE_RETAIN(m_onCancel);
		return self;
	}
	return nil;
}

- (void)dealloc {
    CC_SAFE_RELEASE(m_onOK);
    CC_SAFE_RELEASE(m_onCancel);
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if(buttonIndex == alertView.cancelButtonIndex) {
		if(m_onCancel)
			m_onCancel->execute();
	} else if(buttonIndex == alertView.firstOtherButtonIndex) {
		if(m_onOK)
			m_onOK->execute();
	}
	
    // release
#if !__has_feature(objc_arc)
	[self autorelease];
#endif
}

@end

#pragma mark -
#pragma mark delegate of app store view

@interface SKStoreProductViewControllerDelegate_openAppInStore : NSObject <SKStoreProductViewControllerDelegate>
@end

@implementation SKStoreProductViewControllerDelegate_openAppInStore

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:^{
#if !__has_feature(objc_arc)
        [viewController autorelease];
		[self autorelease];
#endif
    }];
}

@end

#pragma mark -
#pragma mark CCUtils implementation on iOS

NS_CC_BEGIN

void CCUtils::openUrl(const string& url) {
    NSURL* nsUrl = [NSURL URLWithString:[NSString stringWithUTF8String:url.c_str()]];
    [[UIApplication sharedApplication] openURL:nsUrl];
}

void CCUtils::openAppInStore(const string& appId) {
    // XXX: for now we still use web, later we will change
//	if([[UIDevice currentDevice].systemVersion floatValue] < 6.0f) {
		NSString* urlStr = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/us/app/id%s?mt=8", appId.c_str()];
		NSURL* url = [NSURL URLWithString:urlStr];
		[[UIApplication sharedApplication] openURL:url];
//	} else {
//		SKStoreProductViewController* storeProductVC = [[SKStoreProductViewController alloc] init];
//		storeProductVC.delegate = [[SKStoreProductViewControllerDelegate_openAppInStore alloc] init];
//		NSDictionary* dict = [NSDictionary dictionaryWithObject:[NSString stringWithUTF8String:appId.c_str()]
//														 forKey:SKStoreProductParameterITunesItemIdentifier];
//		[storeProductVC loadProductWithParameters:dict completionBlock:^(BOOL result, NSError* error) {
//			if (result) {
//				UIViewController* vc = CCUtils::findViewController([EAGLView sharedEGLView]);
//				[vc presentViewController:storeProductVC animated:YES completion:nil];
//			}
//		}];
//	}
}

UIViewController* CCUtils::findViewController(UIView* view) {
	for (UIView* next = [view superview]; next; next = next.superview) {
		UIResponder* nextResponder = [next nextResponder];
		if ([nextResponder isKindOfClass:[UIViewController class]]) {
			return (UIViewController*)nextResponder;
		}
	}
	
	// try window root view controller
	for (UIView* next = [view superview]; next; next = next.superview) {
		if([next isKindOfClass:[UIWindow class]]) {
			return ((UIWindow*)next).rootViewController;
		}
	}
	
	return nil;
}

void CCUtils::showSystemConfirmDialog(const char* title, const char* msg, const char* positiveButton, const char* negativeButton, CCCallFunc* onOK, CCCallFunc* onCancel) {
	NSString* cancelButtonTitle = negativeButton ? [NSString stringWithUTF8String:negativeButton] : nil;
	NSString* okButtonTitle = positiveButton ? [NSString stringWithUTF8String:positiveButton] : nil;
    string lan = CCLocale::sharedLocale()->getISOLanguage();
	if(cancelButtonTitle == nil) {
		if(lan == "zh")
			cancelButtonTitle = @S_CANCEL_ZH;
		else
			cancelButtonTitle = @S_CANCEL_EN;
	}
	if(okButtonTitle == nil) {
		if(lan == "zh")
			okButtonTitle = @S_OK_ZH;
		else
			okButtonTitle = @S_OK_EN;
	}
    
	// create alert view
	UIAlertView* alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithUTF8String:title]
													message:[NSString stringWithUTF8String:msg]
												   delegate:[[CCSystemConfirmDialogDelegate alloc] initWithOK:onOK cancel:onCancel]
										  cancelButtonTitle:cancelButtonTitle
										  otherButtonTitles:okButtonTitle, nil];
	[alert performSelectorOnMainThread:@selector(show)
							withObject:nil
						 waitUntilDone:NO];
    
    // release
#if !__has_feature(objc_arc)
    [alert release];
#endif
}

void CCUtils::stopInternalMusic() {
    MPMusicPlayerController* mp = [MPMusicPlayerController applicationMusicPlayer];
    [mp stop];
}

void CCUtils::playInternalMusic() {
    MPMusicPlayerController* mp = [MPMusicPlayerController applicationMusicPlayer];
    [mp setQueueWithQuery:[MPMediaQuery songsQuery]];
    [mp play];
}

bool CCUtils::isInternalMusicPlaying() {
    MPMusicPlayerController* mp = [MPMusicPlayerController applicationMusicPlayer];
	return [mp playbackState] == MPMusicPlaybackStatePlaying;
}

void CCUtils::purgeDefaultForKey(const string& key) {
    NSString* nsKey = [NSString stringWithCString:key.c_str() encoding:NSUTF8StringEncoding];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:nsKey];
}

int CCUtils::getCpuHz() {
    // get hardward string
    size_t size = 100;
    char* hw_machine = (char*)malloc(size);
    int name[] = {CTL_HW, HW_MACHINE};
    sysctl(name, 2, hw_machine, &size, NULL, 0);
    string hw = hw_machine;
    free(hw_machine);
    
    // check
    if(startsWith(hw, "iPhone")) {
        string majorMinor = hw.substr(6);
        CCArray& parts = componentsOfString(majorMinor, ',');
        int major = atoi(((CCString*)parts.objectAtIndex(0))->getCString());
        if(major < 4)
            return 500000000;
        else if(major == 4)
            return 800000000;
        else
            return 1500000000;
    } else if(startsWith(hw, "iPod")) {
        string majorMinor = hw.substr(4);
        CCArray& parts = componentsOfString(majorMinor, ',');
        int major = atoi(((CCString*)parts.objectAtIndex(0))->getCString());
        if(major < 4)
            return 500000000;
        else if(major == 4)
            return 800000000;
        else
            return 1500000000;
    } else if(startsWith(hw, "iPad")) {
        string majorMinor = hw.substr(4);
        CCArray& parts = componentsOfString(majorMinor, ',');
        int major = atoi(((CCString*)parts.objectAtIndex(0))->getCString());
        if(major < 2)
            return 500000000;
        else if(major == 2)
            return 800000000;
        else
            return 1500000000;
    } else {
        return 1500000000;
    }
}

bool CCUtils::verifySignature(void* validSign, size_t len) {
    return true;
}

bool CCUtils::isDebugSignature() {
    return false;
}

bool CCUtils::hasExternalStorage() {
    return true;
}

string CCUtils::getInternalStoragePath() {
    NSString* docDir = @"~/Documents";
    docDir = [docDir stringByExpandingTildeInPath];
    return [docDir cStringUsingEncoding:NSUTF8StringEncoding];
}

string CCUtils::getPackageName() {
	NSBundle* bundle = [NSBundle mainBundle];
    NSString* bundleId = [bundle bundleIdentifier];
    return [bundleId cStringUsingEncoding:NSUTF8StringEncoding];
}

bool CCUtils::isPathExistent(const string& path) {
	// if path is empty, directly return
	if(path.empty())
		return false;
	
	NSString* nsPath = [NSString stringWithFormat:@"%s", path.c_str()];
	return [[NSFileManager defaultManager] fileExistsAtPath:nsPath];
}

bool CCUtils::createFolder(const string& path) {
	NSString* nsPath = [NSString stringWithFormat:@"%s", path.c_str()];
	NSFileManager* fm = [NSFileManager defaultManager];
	return [fm createDirectoryAtPath:nsPath withIntermediateDirectories:YES attributes:NULL error:NULL];
}

string CCUtils::externalize(const string& path) {
	if(!CCFileUtils::sharedFileUtils()->isAbsolutePath(path)) {
		NSString* nsPath = [NSString stringWithFormat:@"~/Documents/%s", path.c_str()];
		nsPath = [nsPath stringByExpandingTildeInPath];
		return [nsPath cStringUsingEncoding:NSUTF8StringEncoding];
	} else {
        return path;
	}
}

bool CCUtils::deleteFile(const string& path) {
	NSString* p = [NSString stringWithFormat:@"%s", path.c_str()];
	NSFileManager* fm = [NSFileManager defaultManager];
	NSError* error = nil;
	[fm removeItemAtPath:p error:&error];
	return error == nil;
}

string CCUtils::getAppVersion() {
    NSBundle* bundle = [NSBundle mainBundle];
    NSString* ver = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    return [ver cStringUsingEncoding:NSUTF8StringEncoding];
}

NS_CC_END

#endif // #if CC_TARGET_PLATFORM == CC_PLATFORM_IOS