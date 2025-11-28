Adding a Privacy Manifest in Xcode
As we have seen in a previous lesson, you need to specify your data collection practices to generate privacy labels in App Store Connect. These labels will appear on your App Store listing, as shown below:

App Store Privacy Labels for the Flutter Tips app
But that’s not all! Starting November 12, 2024, Apple also requires you to add a Privacy Manifest to your app before submitting it to App Store Connect.

In this lesson, I’ll show you how to create a Privacy Manifest using the Flutter Ship app as an example.

What is a Privacy Manifest?
A Privacy Manifest is a file named PrivacyInfo.xcprivacy that records your app’s data collection practices and API usage. It helps Apple understand what data is collected and why.

The information in this file should match what you declared in App Store Connect, ensuring consistency between your app’s privacy labels and its internal data practices.

Here’s what the Privacy Manifest looks like in Xcode:

Xcode privacy manifest for the Flutter Ship app
Now, let’s learn how to create it.

How to Create a Privacy Manifest in Xcode
To create a privacy manifest in Xcode, follow these steps:

1. Open your Flutter iOS app in Xcode
Run this command in the terminal:

open ios/Runner.xcworkspace 
2. Create a Privacy Manifest file
In Xcode, right-click the Runner folder and select New File from Template…:

New File from Template...
Scroll down to the Resource section, choose App Privacy, and click Next:

Choosing the App Privacy template
Create the file with the default name PrivacyInfo:

Creating a new file
3. Adding Data to Your Privacy Manifest
Once the PrivacyInfo file is created, you can start adding values.

Click on the + icon next to App Privacy Configuration:

Empty PrivacyInfo file
This will show a dropdown with four options. Choose Privacy Tracking Enabled and leave the boolean value to NO (unless your app collects data for tracking purposes):

Setting the Privacy Tracking Enabled flag
Click on the + icon next to Privacy Tracking Enabled to add a new value, and choose Privacy Tracking Domains from the dropdown. Leave the array empty if your app doesn’t have any tracking domains:

Privacy Tracking domains
Click + again and choose Privacy Nutrition Label Types:

Privacy Nutrition Label Types
This is an array that should match all the data collection types you declared in App Store Connect.

For each item, you have to set four values:

Collected Data Type
Collection Purposes
Linked to User
Used for Tracking
Privacy Nutrition Label Type Options
For each item, use the dropdown to select the appropriate Collected Data Type:

Collected Data Type
The Collection Purposes is an array of strings. Each string can be selected from a dropdown:

Collected Data Type
Now, repeat the process for all the types of data collected by your app:

Collected Data Type
These should match the data collection types you declared in App Store Connect:

Data Collection Types for the Flutter Ship app
There’s one more value to set, called Privacy Accessed API Types:

Collected Data Type
For each item in the array, you have to set a Privacy Accessed API Type and a Privacy Accessed API Reasons.

For example, since the Flutter Ship app uses Shared Preferences, I have set User Defaults (which is the underlying storage on iOS):

Privacy Accessed API Type
As for the Privacy Accessed API Reasons, I have selected User Defaults - CA92.1: Access info from same app, per documentation (this should be correct for most apps):

Privacy Accessed API Reasons
Once all the information is complete, your PrivacyInfo file should look similar to this:

Xcode privacy manifest for the Flutter Ship app
That’s it! Going through this wasn’t much fun, but it gets easier once you’ve done it a couple of times.

Hopefully, this also means that your app will pass app review! 🤞

Privacy Manifests: Key Points
A Privacy Manifest is a file that outlines your app’s data collection practices and API usage. It ensures transparency between your app’s behavior and what you declare to Apple.

It should declare the following information inside the App Privacy Configuration section:

NSPrivacyTracking: Indicates whether your app uses tracking, as defined by Apple’s App Tracking Transparency framework.
NSPrivacyTrackingDomains: Lists internet domains your app uses for tracking purposes.
NSPrivacyCollectedDataTypes: Details the types of data collected by your app (e.g., location, identifiers).
NSPrivacyAccessedAPITypes: Describes the APIs your app accesses and the reasons for their use (e.g., User Defaults for local storage).
Starting November 2024, failing to include this file will prevent your app from being submitted for review on the App Store.

Quiz time!

Question 1 of 3
What is the purpose of a Privacy Manifest in iOS apps?

Declare third-party SDK data collection

Document tracking activities

Identify reasons for API usage

Enable additional security features

Submit
Resources
To learn more about privacy manifests, read the official docs:

Adding a privacy manifest to your app or third-party SDK
Privacy manifest files
Describing data use in privacy manifests
Describing use of required reason API