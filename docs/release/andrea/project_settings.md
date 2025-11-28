Reviewing the Xcode Project Settings
Before building and submitting your app to App Store Connect, it’s crucial to review your Xcode project settings to ensure everything is configured correctly. This step helps you avoid common issues that can arise during the build and submission process.

In this lesson, we’ll walk through the key settings you need to double-check, such as supported destinations, deployment targets, app identity, and more. By the end, you’ll have the confidence that your app is ready for the next steps.

Some of these steps are already outlined on this page in the Flutter docs: Build and release an iOS app. Here, we’ll cover them in detail to ensure you don’t miss any important steps.

Reviewing the Xcode Project Settings
Start by opening the Xcode project:


Copy
open ios/Runner.xcworkspace/
Then, head to Runner > General, and you’ll see these settings:

Runner > Runner > General
Here’s a checklist of things to verify. 👇

Xcode Project Settings Checklist
Update the Supported Destinations if needed
Set the Minimum Deployment Version
Set the App Category inside Identity
Update the supported orientations inside Deployment Info if needed
Verify your App Icons and Launch Screen
Supported Destinations
Only include the destinations your app currently supports. If you want to remove unsupported destinations, you can select them and press the - button:

Removing unsupported destinations
This is handy if you want to target iPhone only in your first release. If you target iPad, you’ll need to do some extra work and make your app responsive and upload iPad screenshots in App Store Connect.

Minimum Deployment
This sets the minimum iOS version your app will support:

Setting the minimum deployment version
When choosing the minimum deployment version, consider this:

iOS users keep their devices updated: By targeting an iOS version that is 2 years old, you’ll capture over 90% of the market share.
Usage of newer APIs: If your app or plugins use newer APIs, ensure this meets the minimum requirements.
Identity
Next, you’ll find the Identity section:

Identity section
This includes the following fields:

App Category: this should match the Category you set in App Store Connect under General > App Information > General Information.
Display Name: This is the name of your app as it will appear on the user’s device (under the app icon). If you leave this empty (recommended), Xcode will use the APP_DISPLAY_NAME variable that was set when you configured flavors with Flutter Flavorizr.
Bundle Identifier: This should match the App ID you created earlier. If you’re using flavors, this is determined by the build configuration, and you should not change it.
Version and Build Number: These are derived from the version field in your pubspec.yaml file and should not be edited in Xcode (more on this later).
Deployment Info
Use this section to decide which orientations are supported by your app:

Deployment Info
If your app is designed to be used in Portrait mode only, untick the Landscape Left and Landscape Right settings.

App Icons and Launch Screen
This section looks like this:

App Icons and Launch Screen
You don’t need to make any changes here. As long as you’ve configured these as described in module 2 and module 3, they should appear correctly Runner > Runner > Assets.

Question 1 of 3
What key settings should you review in your Xcode project before building?

Supported Destinations

Minimum Deployment Version

App Category

Supported Orientations

Submit
Wrapping Up
That’s it! By reviewing these key settings in Xcode, you’ve ensured that your app is configured properly and is ready for the next stage of the release process.

In the next lesson, we’ll explore code signing, certificates, and provisioning profiles, which are necessary for securely uploading your app to App Store Connect.

Let’s keep going!

Resources
Build and release an iOS app