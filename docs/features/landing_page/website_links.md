Adding the Website Links to the Settings Page
Assuming you published your website, Privacy Policy, and Terms of use, it may be a good idea to include the relevant links in your mobile app as well.

A good place to do this is in the settings or about screen:

Preview of the settings screen with the website links
And in this lesson, you’ll learn how to do this, using the Flutter Ship app as reference.

Updated Code Snapshot
To make life easier, I’ve added the latest code to a new branch.

So, let’s discard the latest changes and switch to the m08-website-links branch:


Copy
git reset --hard HEAD && git clean -fd
git switch m08-website-links
Here’s what’s included in the latest snapshot. 👇

Updated Settings Page
If you open lib/src/presentation/settings_screen.dart and scroll to the bottom of the build method, you’ll see this:


Copy
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider).requireValue;
    return Scaffold(
      appBar: AppBar(...),
      body: ResponsiveCenterScrollable(
        child: ListView(
          children: [
            ...
            if (!kIsWeb) ...[
              const RateOnAppStoreTile(),
              const Divider(height: 1),
              // * No need to show the website links on Flutter web
              ListTile(
                title: const Text('Website'),
                onTap: () => _openLink(
                    'https://bizz84.github.io/flutter-ship-landing-page/', ref),
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Privacy Policy'),
                onTap: () => _openLink(
                    'https://bizz84.github.io/flutter-ship-landing-page/privacy/',
                    ref),
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Terms of Use'),
                onTap: () => _openLink(
                    'https://bizz84.github.io/flutter-ship-landing-page/terms/',
                    ref),
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
 
  Future<void> _openLink(String url, WidgetRef ref) async {
    final uri = Uri.parse(url);
    await ref.read(urlLauncherProvider).launch(uri);
  }
}
If you run the app and click on any of the website links, the corresponding page will open with the in-app browser:

Website links are opened with the in-app browser
Opening URLs with the url_launcher package
You can use the url_launcher package to open website links from your app.

Note that in order for the package to work correctly on Android, this query intent is needed in the AndroidManifest.xml file:


Copy
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  ...
  <queries>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="https"/>
    </intent>
  </queries>     
</manifest>
Inside the Flutter Ship app, I’ve also included a helper UrlLauncher class inside lib/src/utils/url_launcher_provider.dart, and this is what is used in the settings screen.

Wrap Up
Once your website is published, it’s very easy to add the relevant links to your app. While this step is optional, it makes it easier for your users to visit your site, share it with others, and read the legal documents.

Time for a quick quiz!