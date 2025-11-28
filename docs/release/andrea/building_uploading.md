Building and Uploading your iOS app to App Store Connect
In this lesson, you’ll learn how to build and upload your iOS app to App Store Connect. We’ll cover:

Automatically managing code signing in Xcode to ensure your app is ready for distribution.
Setting the correct version and build number from your pubspec.yaml.
Using the flutter build ipa command to generate your IPA file.
Uploading the IPA file to App Store Connect using the Apple Transporter macOS app.
Automatically Manage Signing
To get started, select the Runner target and open the Signing & Capabilities tab:

Signing & Capabilities tab in Xcode
You’ll see that Automatically manage signing is checked (Flutter sets this by default).

This is what you want, but it will only work if your select your Team from the dropdown:

Selecting the development team
What if the team is not configured?

Show more



Once the team is set, Xcode will automatically set the Signing Certificate:

Setting the Signing Certificate
What if a provisioning profile can't be generated?

Show more



Development or Distribution Certificate?
If you enable Automatically manage signing and select a team, Xcode will automatically generate the required certificate and provisioning profile for you (if they didn’t already exist).

Note that by default, a development certificate is created (rather than a distribution one). This is normal and won’t prevent you from uploading your app to App Store Connect.

You can find all your certificates in the Apple Developer Portal.

Before continuing, we need to check one more thing. 👇

App Version and Build Number
In Flutter, the version and build number are defined in the pubspec.yaml file under the version key:


Copy
name: flutter_ship_app
description: "Flutter App Release Checklist (companion app for the Flutter in Production course)"
publish_to: 'none'
version: 0.3.4+18
In the example above:

0.3.4 is the version number of your app.
18 is the build number, which you should increment with each new update or build.
These values are automatically mapped to the corresponding iOS properties in Xcode:

CFBundleShortVersionString: This represents the app’s version number (e.g., 0.3.4).
CFBundleVersion: This represents the build number (e.g., 18).
When you build your app, Flutter sets these values from the FLUTTER_BUILD_NAME and FLUTTER_BUILD_NUMBER variables derived from the pubspec.yaml file:

CFBundleShortVersionString and CFBundleVersion
Both the version and the build number can be overridden in flutter build ipa by specifying --build-name and --build-number, respectively.

Important: Apple requires that the build number is incremented for every new build uploaded to App Store Connect. If you try to upload a build with the same build number as a previous one, the upload will fail.

Setting the App Version in App Store Connect
In App Store Connect, you’ll need to manually set the app version number to match the version in your pubspec.yaml. Here’s how:

Go to App Store Connect > My Apps > Your App.
Scroll down to the metadata and set the correct version number to match what’s in your pubspec.yaml:
Setting the Version Number in App Store Connect
Building the App Bundle
Once you’ve verified your settings and versioning, it’s time to build the app bundle that will be uploaded to App Store Connect.

To create the iOS app bundle, run the following command:


Copy
flutter build ipa
Depending on how your app is configured, you’ll need to pass some additional flags. To see a list of all supported arguments, run: flutter build ipa --help.

If your app supports multiple flavors (like Flutter Ship), you can specify a flavor using the --flavor flag. For example:


Copy
# To build the stg flavor
flutter build ipa --flavor stg -t lib/main_stg.dart --dart-define-from-file=.env.stg
When building your iOS app for release, you’ll want to use the prod flavor. Here I used the stg flavor for illustration purposes only.

Here’s the output from running the command above on my machine:


Copy
Archiving com.codewithandrea.flutterShipApp.stg...
Automatically signing iOS for device deployment using specified development team in Xcode project: M54ZVB688G
Running Xcode build...                                                  
 └─Compiling, linking and signing...                         6.6s
Xcode archive done.                                         70.9s
✓ Built build/ios/archive/Runner.xcarchive (238.7MB)
 
[✓] App Settings Validation
    • Version Number: 0.3.4
    • Build Number: 18
    • Display Name: Flutter Ship Stg
    • Deployment Target: 16.6
    • Bundle Identifier: com.codewithandrea.flutterShipApp.stg
 
To update the settings, please refer to https://flutter.dev/to/ios-deploy
 
Building App Store IPA...                                          59.5s
✓ Built IPA to build/ios/ipa (56.4MB)
To upload to the App Store either:
    1. Drag and drop the "build/ios/ipa/*.ipa" bundle into the Apple Transporter macOS app
    https://apps.apple.com/us/app/transporter/id1450874784
    2. Run "xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa --apiKey your_api_key --apiIssuer your_issuer_id".
       See "man altool" for details about how to authenticate with the App Store Connect API key.
This will generate an IPA (iOS App Archive) file, which is the format used to distribute iOS apps. The IPA will be located in the build/ios/ipa/ directory.

Note about allowing Keychain Access
In order to sign the app, the flutter build ipa command needs to access the certificates stored in your computer’s keychain. When this happens, you may get a popup that asks for your password. To get past this, enter your computer password and click Always allow.

Note about Obfuscation

Show more



Copy


Uploading the App Bundle to App Store Connect
There are multiple ways to upload your app bundle to App Store Connect, but for now, I recommend using Apple Transporter.

Why? It’s the simplest, most user-friendly method for uploading your app bundle, especially if you’re new to the process. It handles the upload and validation for you, without requiring any extra setup or API configuration.

We’ll cover more advanced options, including xcrun, in a later lesson.

Using the Apple Transporter macOS App (Easier for Now)
The Apple Transporter app is the simplest way to upload your IPA file to App Store Connect.

Download and install the Transporter app from the Mac App Store.
Open Transporter and sign in with your Apple Developer account.
Welcome to Transporter
Drag and drop your IPA file into the app or add it with the + button at the top, then click Deliver to upload it:
Transporter app
The app will now go through multiple stages:

Transporter app - uploadingTransporter app - processing
After a few minutes, it will show as “Ready for Internal Testing”:

Transporter app - ready for testing
You’ll also receive an email from Apple confirming that your build has been successfully uploaded.

In the next lesson, you’ll learn how to submit your app for review.

But first, time for a quiz!

Question 1 of 3
What command is used to build an iOS app for distribution with Flutter?

flutter build ios

flutter build ipa

flutter run --release

flutter create ipa

Submit
Resources
Build and release an iOS app
Apple Transporter macOS app
Submit Feedback
