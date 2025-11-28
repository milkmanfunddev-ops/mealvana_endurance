Submitting App Updates to App Store Connect
Submitting an app update to the App Store is much quicker and smoother compared to the initial submission process. You won’t need to go through all the setup steps again—just a few updates to your app’s metadata, upload a new build, and you’re set.

However, while the process is straightforward, it’s crucial to update your app’s version number and build number are correctly updated, otherwise your upload to fail, leading to delays.

This lesson will guide you through the necessary steps.

Submitting a New App Version
To submit a new app version, follow these steps:

1. Add a New Version
In App Store Connect, navigate to your app’s main page. Click the + button next to the current version number:

Adding a new version
2. Enter the Version Number
Enter the new version number (e.g., 1.2.9) and click Create. The app will then move into the Prepare for Submission state:

Choosing the version numberPreparing for submission
3. Update Metadata
You’ll need to update your app’s metadata for the new version. This includes filling out the What’s New in This Version section, which will appear on your App Store listing:

Preparing for submission
4. Update the App Version and Build Number
Before creating and uploading a new build, you need to update the version and build number in the pubspec.yaml file:


Copy
version: 1.2.9+51
1.2.9 is the version number, which will map to CFBundleShortVersionString in Xcode.
51 is the build number, which will map to CFBundleVersion in Xcode.
What's the Difference between App Version and Build Number?
Version Number: This is the public version of your app that users will see in the App Store. You should update this every time you release a new version.
Build Number: This is the internal version used to differentiate between builds of the same app version. You must increment the build number with each new submission, even if the version number stays the same (e.g., when resubmitting after a rejection).
Important: If you forget to increment the build number, the upload will fail with an error, and you’ll have to make a new build.

5. Upload a New Build
After updating the metadata, you can make a new build with the Flutter CLI:


Copy
# To build the prod flavor
flutter build ipa --flavor prod -t lib/main_prod.dart --dart-define-from-file=.env.prod
Once the build is ready, you have two options to upload it:

Use the Transporter app (easier but slower): This is a simple, user-friendly method for uploading builds, which we covered in the previous lesson.
Use the xcrun command (more setup but faster): If you want to streamline the process and make it faster, especially for frequent updates or CI/CD pipelines, the xcrun method is more efficient. We’ll cover this in detail in the next lesson.
6. Submit for Review
After everything is updated, click Add for Review, then Submit to App Review and wait for the app to be reviewed.

Wrapping Up
Submitting a new version of your app to App Store Connect is a quick process once you’ve updated your app’s version and build number and reviewed your metadata. Follow the steps above to ensure your app update is ready for review without any hiccups.

Time for a quiz!

Question 1 of 3
What must be updated in pubspec.yaml when submitting a new app version?

Version number

Build number

App name

Bundle ID

Submit
Next Steps
As you continue to release updates, you’ll want to speed up the process even further. But how?

In the next lesson, we’ll cover how to upload app builds faster using xcrun and the App Store Connect API. This method is especially useful if you want to streamline your submission process or integrate it with CI/CD pipelines for automated deployments. Let’s take your app submission process to the next level!