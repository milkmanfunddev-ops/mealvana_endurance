Preparing for Review: App Privacy and Data Collection
In this lesson, we’ll focus on declaring your app’s privacy practices in App Store Connect. This step is crucial, as it affects your app’s privacy labels on the App Store, which inform users about the types of data your app collects and how that data is used:

App Store Privacy Labels for the Flutter Tips app
You’ll be required to provide details on your app’s privacy policy and disclose any data collection practices—whether your app collects data directly or through third-party services like Mixpanel and Sentry.

Let’s get started by setting up your app’s privacy information.

Privacy Policy
From the side menu, navigate to App Store > App Privacy, and you’ll see this page:

App Privacy
Click on Edit, then enter your Privacy Policy URL and click Save:

Setting the Privacy Policy URL
If you need help generating a privacy policy, check out this lesson: How to Generate the Privacy Policy and Terms of Use.

Data Collection
Next, you’ll need to disclose your app’s data collection practices. Click on Get Started:

Data Collection - Get Started
If your app collects data—either directly or through third-party services like analytics or error monitoring—select Yes:

Data Collection
In the next step, you’ll need to specify the types of data your app collects by filling out a detailed form:

Data Collection Types
For the Flutter Ship app, I’ve selected the following data types: Coarse Location, Device ID, Product Interaction, Crash Data, Performance Data, and Other Diagnostics Data. These types are used by Mixpanel and Sentry for analytics and diagnostics:

Data Collection Types for the Flutter Ship app
How to determine the data collection types?
If you’re unsure about your app’s data collection practices, refer to App privacy details on the App Store. The sections on User Tracking and Additional Guidance will help clarify what data types apply to your app.

Providing Additional Information for Each Data Type
After clicking Save, you’ll need to provide more details for each data type you declared. You’ll be prompted with this message:

Additional Setup Required
Back on the App Privacy page, click on each data type to provide more information:

Setup Data Types
Example: Coarse Location
Let’s walk through an example for Coarse Location.

Click on the Coarse Location box, and you’ll see this dialog:

Coarse Location step 1
Select the purpose for collecting this data. For example, Flutter Ship uses Mixpanel to derive coarse user location from their IP address, so I chose Analytics.

On the next page, declare whether the data is linked to the user’s identity. In this case, I selected No because I haven’t enabled user-tracking features in Mixpanel:

Coarse Location step 2
The following steps are informational. Just click Next:

Coarse Location: tracking and third-party dataCoarse Location: tracking examples
Finally, determine whether your app uses coarse location for tracking purposes, then click Save:

Coarse Location tracking question
Repeat for Other Data Types
You’ll need to repeat this process for each data type you’ve selected. For example:

Other data collection types
Once you’ve completed all the data types, your app’s Product Page Preview will generate the privacy labels, and you can click Publish to finalize your privacy information:

Product Page Preview
Wrapping Up
Declaring your app’s privacy practices is a critical step in ensuring transparency with your users and complying with Apple’s App Store policies. By filling out the App Privacy section and accurately disclosing your data collection practices, you’re helping users make informed decisions about your app.

Time for a quiz!

Question 1 of 3
What information is required in the App Privacy section?

Data types the app collects

How collected data is used

Third-party analytics tools

Privacy policy URL

Submit
Next, we’ll move on to Pricing and Availability, where you’ll set your app’s price, availability in different regions, and distribution model. Let’s continue.

Resources
App privacy details on the App Store
User Tracking
Additional Guidance
User privacy and data use
App Tracking Transparency framework