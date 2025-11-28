Uploading Builds with xcrun and the App Store Connect API
Using xcrun and the App Store Connect API to upload app builds can significantly speed up the submission process compared to using the Apple Transporter app. This method is particularly useful for developers who frequently need to submit updates or want to automate their workflows in CI/CD pipelines.

In this lesson, we’ll walk through how to:

Submit app builds using xcrun.
Authenticate using your Apple ID or an App Store Connect API key (recommended for automation).
Obtain and configure an App Store Connect API key.
Automate the build and submission process with a simple script.
By the end of this lesson, you’ll have a faster, more efficient workflow for submitting app updates, saving time and reducing manual effort.

What is Xcrun?
xcrun is a command-line utility for locating and invoking developer tools in the currently active Xcode toolchain. While it has many use cases, here we will use it specifically to upload ipa files to App Store Connect.

How to install xcrun?
If xcrun is not installed on your machine, simply run xcode-select --install and follow the instructions.

Alternatively, download and install the Command line tools for Xcode from the Xcode Downloads page:

Command line tools for Xcode
Then, you can verify the installation by running xcrun --version.

Authenticating with App Store Connect using xcrun
Consider this command, which is used to upload the ipa file built via flutter build ipa:


Copy
xcrun altool --upload-app --type ios --file build/ios/ipa/*.ipa
If you don’t provide authentication credentials, the command will fail:


Copy
NSLocalizedDescription = "Unable to upload archive.";
NSLocalizedFailureReason = "You must specify authentication credentials (username/password or apiKey/apiIssuer).";
There are two ways to authenticate:

1. Username and Password
This method uses your Apple ID credentials to authenticate with App Store Connect:


Copy
xcrun altool --upload-app --type ios --file build/ios/ipa/*.ipa --username YOUR_APPLE_ID --password YOUR_PASSWORD
When to Use: This method is straightforward for occasional uploads but not ideal for automation or CI/CD pipelines, as it requires securely storing your Apple ID credentials.

Note about App-Specific Passwords and 2FA
If you have two-factor authentication (2FA) enabled for your Apple ID (recommended), you’ll need to generate an App-Specific Password instead of using your regular Apple ID password. Follow these steps to create one:


Show more

Copy
2. API Key and API Issuer (Recommended)
This method uses an App Store Connect API key for authentication and is the preferred option for most developers, especially when automating workflows.

Example command:


Copy
xcrun altool --upload-app --type ios --file build/ios/ipa/*.ipa --apiKey APP_STORE_CONNECT_KEY_ID --apiIssuer APP_STORE_CONNECT_ISSUER_ID
Why Use This Method?

More Secure: You don’t need to store sensitive Apple ID credentials.
Automation-Ready: It’s ideal for CI/CD pipelines or script-based workflows.
Team-Friendly: API keys can be securely shared among team members or used across automation tools.
Now, let’s walk through how to obtain and configure an App Store Connect API key.

Obtaining an App Store Connect API Key
Follow these steps to create an API key:

Step 1: Go to App Store Connect
Navigate to App Store Connect.
Select Users and Access from the main dashboard.
Step 2: Create an API Key
In the Integrations tab, click the + button to create a new API key.
App Store Connect Integrations
Enter a name for the key (e.g., “API Key for Build Uploads”).
Assign the role of App Manager, which grants permission to manage the app and submit updates.
Click Generate.
Generate API Key
Step 3: Note Down the API Key Details
Once the key has been generated, click Download from the list of API Keys.

List of API keys
Note that API key can only be downloaded once, so don’t lose it:

Download API key
Important: Once you have downloaded the key file (.p8), move it into any of these folders:

~/private_keys
~/.private_keys
~/.appstoreconnect/private_keys
The xcrun command will fail if it can’t find the file with the given Key ID inside those folders.

Submitting the IPA with Xcrun
Once you have your App Store Connect API key, use the following command to upload your IPA file via xcrun:


Copy
xcrun altool --upload-app --type ios --file build/ios/ipa/*.ipa --apiKey APP_STORE_CONNECT_KEY_ID --apiIssuer APP_STORE_CONNECT_ISSUER_ID
Let’s break this down:

altool: This is the Apple tool used to upload apps to App Store Connect.
-upload-app: Specifies that you’re uploading an app.
-type ios: Specifies that the app is an iOS app.
-file build/ios/ipa/*.ipa: The path to your IPA file.
-apiKey APP_STORE_CONNECT_KEY_ID: The Key ID you received when generating the API key (this corresponds to the AuthKey_<KeyID>.p8 file you have downloaded).
-apiIssuer APP_STORE_CONNECT_ISSUER_ID: Your Issuer ID (from App Store Connect).
If everything goes well, after a few minutes you’ll receive an email confirming that the build has been uploaded successfully.

Common Errors and Fixes
Invalid Version or Build Number: Update the version and build number in your pubspec.yaml file before uploading.
Invalid API Key or Issuer: Double-check your API Key (APP_STORE_CONNECT_KEY_ID) and Issuer ID (APP_STORE_CONNECT_ISSUER_ID) values.
File Not Found: Verify the path to your .ipa file in the --file argument.
If any errors occur during the upload, they will be printed in the console. Here’s an example of an error caused by a duplicate build number:


Copy
Running altool at path '/Applications/Xcode-16.1.app/Contents/SharedFrameworks/ContentDeliveryServices.framework/Frameworks/AppStoreService.framework/Support/altool'...
2024-11-20 14:49:53.175 *** Error: [ContentDelivery.Uploader.117E0D650] The provided entity includes an attribute with a value that has already been used (-19232) The bundle version must be higher than the previously uploaded version: ‘18’. (ID: 8970f676-96e1-44c6-971a-066a5f635486)
2024-11-20 14:49:53.177 *** Error: Error uploading 'build/ios/ipa/Flutter Ship Stg.ipa'.
2024-11-20 14:49:53.178 *** Error: The provided entity includes an attribute with a value that has already been used The bundle version must be higher than the previously uploaded version: ‘18’. (ID: 8970f676-96e1-44c6-971a-066a5f635486) (-19232)
 {
    NSLocalizedDescription = "The provided entity includes an attribute with a value that has already been used";
    NSLocalizedFailureReason = "The bundle version must be higher than the previously uploaded version: \U201818\U2019. (ID: 8970f676-96e1-44c6-971a-066a5f635486)";
    NSUnderlyingError = "Error Domain=IrisAPI Code=-19241 \"The provided entity includes an attribute with a value that has already been used\" UserInfo={status=409, detail=The bundle version must be higher than the previously uploaded version., source={\n    pointer = \"/data/attributes/cfBundleVersion\";\n}, id=8970f676-96e1-44c6-971a-066a5f635486, code=ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE, title=The provided entity includes an attribute with a value that has already been used, meta={\n    previousBundleVersion = 18;\n}, NSLocalizedDescription=The provided entity includes an attribute with a value that has already been used, NSLocalizedFailureReason=The bundle version must be higher than the previously uploaded version.}";
    "iris-code" = "ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE";
    previousBundleVersion = 18;
}
Automating Builds with a Local Build Script
Now that you have an App Store Connect API key, you can automate the process of building and uploading your app to the App Store with a simple shell script. This is especially useful if your app supports multiple environments (e.g., dev, stg, prod) and flavors.

Here’s an example of how to run the commands manually for the prod flavor:


Copy
flutter build ipa --flavor prod -t lib/main_prod.dart --dart-define-from-file=.env.prod
xcrun altool --upload-app --type ios --file build/ios/ipa/*.ipa --apiKey APP_STORE_CONNECT_KEY_ID --apiIssuer APP_STORE_CONNECT_ISSUER_ID
To save time and reduce manual effort, you can create the following release-ios.sh script to automate the process:


Copy
#!/bin/bash
# Script to build and upload the ipa file to App Store Connect
 
# Exit immediately if any command fails
set -e
 
# Check if the environment (e.g., dev, stg, prod) is provided as an argument
if [[ $# -eq 0 ]]; then
  echo "No environment specified. Use 'dev', 'stg', or 'prod'."
  exit 1
fi
 
FLAVOR=$1 # First argument specifies the flavor (e.g., dev, stg, prod)
 
# Validate that the API Key ID and Issuer ID are set
if [[ -z ${APP_STORE_CONNECT_KEY_ID} ]]; then
  echo "Key ID is missing. Please set APP_STORE_CONNECT_KEY_ID as an environment variable."
  exit 1
fi
 
if [[ -z ${APP_STORE_CONNECT_ISSUER_ID} ]]; then
  echo "Issuer ID is missing. Please set APP_STORE_CONNECT_ISSUER_ID as an environment variable."
  exit 1
fi
 
# Start from a clean slate
# This ensures that there's only one *.ipa inside build/ios/ipa when uploading with xcrun
flutter clean
flutter pub get
 
# Build the IPA file using Flutter
echo "Building the IPA for flavor: ${FLAVOR}..."
flutter build ipa --flavor ${FLAVOR} -t lib/main_${FLAVOR}.dart --dart-define-from-file=.env.${FLAVOR}
 
# Upload the IPA file to App Store Connect using xcrun
echo "Uploading the IPA to App Store Connect..."
xcrun altool --upload-app --type ios --file build/ios/ipa/*.ipa --apiKey ${APP_STORE_CONNECT_KEY_ID} --apiIssuer ${APP_STORE_CONNECT_ISSUER_ID}
Then, you can set the required environment variables and run the script like this:


Copy
export APP_STORE_CONNECT_KEY_ID=your-key-id
export APP_STORE_CONNECT_ISSUER_ID=your-issuer-id
./release-ios.sh stg
Even better—you can store those environment variables inside ~/.zshrc (if you’re on macOS) to avoid setting them manually every time you open a new terminal.

In the upcoming modules about CI/CD, we’ll revisit this approach and learn how to work with environment variables and secrets to store your API credentials securely.

Wrapping Up
Submitting app updates with xcrun and the App Store Connect API provides a faster, more automation-friendly alternative to the Apple Transporter app. Once you’ve set up your API key, you can automate the entire process with a simple script—ideal for frequent updates or CI/CD workflows.

Time for a quiz!

Question 1 of 3
What are the advantages of using xcrun for uploads?

Faster than Transporter app

Can be automated in scripts

Works with CI/CD pipelines

Doesn't require Apple ID

Submit
Resources
App Store Connect API
Creating API Keys for App Store Connect API