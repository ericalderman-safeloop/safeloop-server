# Push Notifications Setup Guide

This document explains how to complete the push notification setup for SafeLoop.

## What's Already Implemented

### Server-Side (safeloop-server)
✅ Database schema updated with push token fields (`apns_token`, `fcm_token`, `push_notifications_enabled`)
✅ Edge Function updated to send push notifications to assigned caregivers
✅ iOS push notification support via Firebase Cloud Messaging (FCM)
✅ Android push notification support via FCM
✅ Critical alert support for iOS 15+

### Client-Side (safeloop-care)
✅ PushNotificationService created with full notification lifecycle management
✅ Auto-registration on user login
✅ Token refresh handling
✅ Foreground/background notification handlers
✅ Integration with AuthContext

## What You Need to Do

### 1. Install Firebase Dependencies

In the `safeloop-care` directory, install the required packages:

```bash
cd safeloop-care
npm install @react-native-firebase/app @react-native-firebase/messaging
npx pod-install  # For iOS
```

### 2. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or use existing project
3. Name it "SafeLoop" (or your preferred name)
4. Disable Google Analytics (optional)
5. Create project

### 3. Add iOS App to Firebase

1. In Firebase Console, click the iOS icon to add iOS app
2. iOS bundle ID: Get this from your Xcode project (e.g., `com.safeloop.care`)
3. Download `GoogleService-Info.plist`
4. Add it to your Xcode project:
   - Open Xcode
   - Drag `GoogleService-Info.plist` into the project navigator
   - Make sure it's added to the app target
   - Put it in the root of the app folder

### 4. Add Android App to Firebase

1. In Firebase Console, click the Android icon to add Android app
2. Android package name: Get this from `android/app/build.gradle` (e.g., `com.safeloop.care`)
3. Download `google-services.json`
4. Place it in `safeloop-care/android/app/google-services.json`

### 5. Configure iOS for Push Notifications

#### A. Update Info.plist

Add these keys to `safeloop-care/ios/[YourApp]/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

#### B. Update AppDelegate

In `safeloop-care/ios/[YourApp]/AppDelegate.mm`, add:

```objc
#import <Firebase.h>
#import <UserNotifications/UserNotifications.h>

// At the top of didFinishLaunchingWithOptions
[FIRApp configure];

// For push notification registration
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  [FIRMessaging messaging].APNSToken = deviceToken;
}
```

#### C. Enable Push Notifications Capability

1. Open Xcode
2. Select your project target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" and check "Remote notifications"

#### D. Create APNs Key in Apple Developer

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles → Keys
3. Click "+" to create new key
4. Name it "SafeLoop APNs"
5. Check "Apple Push Notifications service (APNs)"
6. Download the `.p8` file (SAVE THIS - you can't download it again!)
7. Note the Key ID

### 6. Upload APNs Key to Firebase

1. In Firebase Console, go to Project Settings (gear icon)
2. Click "Cloud Messaging" tab
3. Scroll to "Apple app configuration"
4. Upload your APNs key (.p8 file)
5. Enter Key ID and Team ID (from Apple Developer)

### 7. Get Firebase Server Key for Supabase

1. In Firebase Console → Project Settings → Service Accounts
2. Click "Generate New Private Key"
3. Download the JSON file (contains service account credentials)
4. This is what you'll use for `FCM_SERVER_KEY`

### 8. Configure Supabase Environment Variables

Set these secrets in Supabase Dashboard (Settings → Edge Functions):

```bash
FCM_SERVER_KEY=<contents of Firebase service account JSON file>
FIREBASE_PROJECT_ID=<your-firebase-project-id>
```

To set secrets:
```bash
supabase secrets set FCM_SERVER_KEY=<paste-json-here>
supabase secrets set FIREBASE_PROJECT_ID=<your-project-id>
```

### 9. Deploy Edge Function

```bash
cd safeloop-server
supabase functions deploy create-help-request
```

### 10. Test End-to-End

1. Run the safeloop-care app on a physical iOS device (push doesn't work on simulator)
2. Log in as a caregiver
3. Check logs to verify push token registration
4. Assign yourself to a wearer
5. Trigger a help request from the watch
6. You should receive a push notification!

## Troubleshooting

### "No push token received"
- Make sure you're on a physical device, not simulator
- Check that notification permissions were granted
- Verify `GoogleService-Info.plist` is in Xcode project

### "Push sent but not received"
- Check Firebase Console → Cloud Messaging → Send test message
- Verify APNs key is uploaded correctly
- Check device is registered with correct bundle ID
- Make sure app is in foreground or background (not force-closed)

### "Invalid token error"
- Token might be for wrong environment (dev vs production)
- Make sure bundle IDs match between Xcode and Firebase
- Try deleting app and reinstalling

## Architecture Overview

```
Watch (safeloop-watch)
  → Sends help request to create-help-request Edge Function
     → Edge Function creates help request in database
     → Edge Function calls get_caregivers_for_help_request
     → For each assigned caregiver:
        → Fetches apns_token/fcm_token from users table
        → Sends push notification via FCM
           → iOS: FCM → APNs → Device
           → Android: FCM → Device

Care App (safeloop-care)
  → On login, registers for push notifications
  → Gets FCM token (works for both iOS and Android)
  → Saves token to users table
  → Listens for incoming notifications
```

## Security Notes

- APNs tokens are device-specific and change when app is reinstalled
- Tokens stored in database with RLS policies (only user can update their own)
- Push notifications only sent to caregivers with `push_notifications_enabled = true`
- Critical alerts used for iOS to bypass Do Not Disturb (requires special entitlement)

## Next Steps

After iOS is working:
- [ ] Test on Android device
- [ ] Add Twilio SMS fallback for critical alerts
- [ ] Add notification preferences UI in settings
- [ ] Add notification history/log
- [ ] Test with multiple caregivers
- [ ] Test with different notification states (foreground, background, quit)
