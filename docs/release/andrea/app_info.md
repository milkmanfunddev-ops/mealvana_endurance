Preparing for Review: App Information
In this lesson, we’ll focus on the App Information page in App Store Connect:

App Information page in App Store connect
This is where you’ll provide key information about your app, such as its name, categories, age rating, and content rights. Each of these elements impacts how your app is presented on the App Store and can directly affect App Store Optimization (ASO) and compliance with Apple’s policies.

Let’s walk through the essential steps.

App Information
On the this page, you can enter the Name, Subtitle, and the Primary and Secondary Category for your app:

App Information
Impact of Choosing Categories for ASO
Choosing the primary and secondary category plays a crucial role in your app’s discoverability.

Primary Category: Defines your app’s core functionality and determines where it appears in category-specific searches. Choose a category with the right balance of relevance and competition.
Secondary Category: Offers additional visibility in another category, useful if your app spans multiple functionalities.
Tips:

Select a less crowded category to improve your chances of ranking.
Ensure the categories accurately reflect your app to attract the right audience.
Categories can affect your chances of being featured by Apple, so consider where your app fits best.
Choosing the right categories can significantly boost your App Store Optimization (ASO) and increase downloads.

Content Rights Information
If your app includes third-party content (e.g., music, videos, or images), you’ll need to provide details about your content rights. Click on Set Up Content Rights Information and select the appropriate option for your app:

App Information
Age Rating
The next section is Age Rating, which determines the content rating for your app based on its content and functionality. This rating will be shown to users in the App Store.

Scroll down to the Age Rating section and click Set Age Rating:

Age Rating
Set the age rating level for each item on the list, depending on your app’s content, then click Next:

Age Rating Levels
Answer the Yes/No questions about specific content types:

Age Rating Questions
Set the Age Categories if needed:

Age Rating Questions
Once that’s done, Apple will generate the Global and Regional Rating Labels that will appear on your app’s listing:

Age Rating Confirmation
App Encryption Documentation
If your app uses encryption, such as HTTPS or encrypted data storage, you’ll need to provide details about the type of encryption used:

App Encryption Documentation
If your app doesn’t use non-exempt encryption (most apps fit this criteria), follow these steps:

Open the iOS project in Xcode
Go to Runner > Runner > Info
Click on the small + icon next to Information Property List
Add a ITSAppUsesNonExemptEncryption key and set the value to NO
Setting the ITSAppUsesNonExemptEncryption flag in Xcode
Setting this flag will prevent extra encryption documentation steps when uploading your builds to App Store Connect (more on this later).

To learn more, read: Complying with Encryption Export Regulations.

Wrapping Up
Once you’ve completed the App Information section, click Save at the top of the page.

In the next lesson, we’ll cover App Privacy and how to detail your app’s data collection practices.

But first, time for a quiz!

Question 1 of 2
What is the purpose of setting the ITSAppUsesNonExemptEncryption flag?

Avoid additional encryption documentation steps

Enable encryption features in your app

Make your app more secure

Required for all apps using HTTPS

Submit
Resources
Complying with Encryption Export Regulations
ITSAppUsesNonExemptEncryption