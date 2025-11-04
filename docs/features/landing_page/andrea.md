Landing Page Template: Setup Guide
When creating a landing page for my Flutter tips app, I considered a few options:

Write it from scratch with HTML & CSS
Buy a paid template Envato Market and customise it
Use a no-code tool like WebFlow or Framer
All these options seemed too time consuming and overly complex, so I kept digging until I discovered this Automatic App Landing Page template, which has over 3K stars on GitHub.

And in this lesson, you’ll learn how to use it to create a website for your app.

How does the template work?
Automatic App Landing Page is a template based on Jekyll, a simple static site generator.

You can use it to:

customize your site by changing some properties in the _config.yml file
add a custom video or screenshot
write the privacy policy, terms of use, and changelog as Markdown files
easily publish your site to GitHub pages
Landing Page Setup Checklist ✅
To set up your site from the template, you can follow the steps in the README.

Here, I include more detailed instructions and some extra tips you may find useful. 👇

Landing Page Setup Checklist ✅
To setup your landing page, follow these steps:

Fork the repo
Customize the metadata in _config.yml, which includes:
App info
Information About Yourself
Feature List
Theme Settings
Update the images
Update the Privacy Policy and Terms of Use
Add a social media banner (optional)
Add website analytics (optional)
Test the site locally
Deploy to GitHub Pages
1. Fork the repo
The first step is to open this repo and fork it:

How to fork the repo
When you do this, choose a name that represents your app (e.g. flutter-tips-landing-page).

Then, clone the project locally so you can make changes:


Copy
git clone https://github.com/your-username/your-forked-repo-name
How to clone the repo (alternative)

Show less
GitHub will let you create only one fork per project on your account. If you want to publish another landing page for a separate app and try to fork again, you’ll won’t be able to proceed:

Fork already exists
To work around this, go to github.new, create a new private repository, and copy the generated URL:

GitHub Quick Setup
Then, clone the original repo and change the remote URL like this:


Copy
git clone https://github.com/emilbaehr/automatic-app-landing-page
# TODO: Rename the folder as desired
mv automatic-app-landing-page your-app-landing-page
cd your-app-landing-page
# TODO: Use your repo URL here
git remote set-url origin https://github.com/your-username/new-repository.git
git push origin master
2. Customize the metadata in _config.yml
Open the project in VSCode and edit the _config.yml:

The _config.yml file in VSCode
App Info
Go ahead and update all this information:


Copy
#page title
page_title                                :                                           # Automatically populates with app name if not set and if iOS app ID is set. Otherwise enter manually.
 
# App Info
ios_app_id                                : 1234793120                                # Required. Enter iOS app ID to automatically populate name, price and icons (e.g. 718043190).
ios_app_country                           : us                                        # Required outside USA. Enter 2 letter country code as in https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
 
appstore_link                             :                                           # Automatically populates if not set and if iOS app ID is set. Otherwise enter manually.
playstore_link                            :                                           # Enter Google Play Store URL.
presskit_download_link                    : https://emilbaehr.com                                          # Enter a link to downloadable file or (e.g. public Dropbox link to a .zip file). Or upload your press kit file to assets and set path accordingly (e.g. "assets/your_press_kit.zip").
app_icon                                  : # assets/appicon.png                      # Automatically populates if not set and if iOS app ID is set.  Otherwise enter path to icon file manually.
app_name                                  :                                           # Automatically populates if not set and if iOS app ID is set.  Otherwise enter manually.
app_price                                 :                                           # Automatically populates if not set and if iOS app ID is set.  Otherwise enter manually.
app_description                           : Write a short tagline for your app.
 
enable_smart_app_banner                   : true                                      # Set to true to show a smart app banner at top of page on mobile devices.
The most important properties are the ios_app_id and playstore_link. Make sure you update them once you create your app in the stores.

Where to find the iOS app ID?
On iOS, the app ID is only known after the app is created in App Store Connect:

The app ID is only known after an app is created in App Store Connect
You’ll learn how to use App Store Connect and the Google Play Console in the upcoming modules.

Information About Yourself
Update all the information about yourself:


Copy
# Information About Yourself
your_name                                 : Emil Baehr                                
your_link                                 : https://emilbaehr.com                     
your_city                                 : Copenhagen                                
email_address                             : emil.baehr@gmail.com
facebook_username                         :                                           
instagram_username                        : ebaehr
twitter_username                          : ebaehr
github_username                           : emilbaehr
youtube_username                          :
mastodon_link                             : https://mastodon.social/@ebaehr
This information will be shown in the footer at the bottom of your site.

Feature List
If you scroll down, you’ll find this list of features:


Copy
# Feature List                            Edit, add or remove features to be presented.
features                                  :
 
  - title                                 : GitHub Pages Jekyll Theme
    description                           : Designed for GitHub Pages. Fork. Edit _config.yml. Upload screenshot/video. Push to gh-pages branch. Voilá!
    fontawesome_icon_name                 : magic
    
  - title                                 : iPhone Device Preview
    description                           : Preview your app in the context of an iPhone device. Five different device colors included.
    fontawesome_icon_name                 : mobile
Use this to highlight the best features in your app.

You’ll also need to find matching icons from the FontAwesome icon set. Note that the landing page works with the older v5 icons:

https://fontawesome.com/v5/search
Theme Settings
At the bottom of the _config.yml you’ll find theme settings such as these:


Copy
# Theme Settings
topbar_color                              : "#000000"
topbar_transparency                       : 0.1
topbar_title_color                        : "#ffffff"
 
cover_image                               : assets/headerimage.png                    # Replace with alternative image path or image URL.
cover_overlay_color                       : "#363b3d"
cover_overlay_transparency                : 0.8
Feel free to customize them as needed.

3. Update the images
Time to update images for the site. You’ll want to replace these files with your own:

assets/screenshot/yourscreenshot.png
assets/headerimage.png
assets/appicon.png
A few notes:

Your screenshot resolution should be 828x1792, 1125x2436, or 1242x2688.
The header image and app icon should match the app_icon and cover_image paths set in the _config.yml.
You can use the launcher icon in your Flutter project as the app icon.
4. Update the Privacy Policy and Terms of Use
We’ll see how to generate the Privacy Policy and Terms of Use in this lesson.

For now, note that they can be stored as .md files inside the _pages folder:

The privacypolicy.md file is stored inside the _pages folder
5. Add a social media banner (optional)
If you plan on sharing your landing page on social media, it’s a good idea to add a banner that will be used as an image preview. Example:

Social media banner
As a result, the banner will show when the site link is shared on X or LinkedIn:

Social media banner preview on X
You can design your banner in Figma and save it to the desired location in your project (e.g. /assets/social-media-banner.png).

Then, open _includes/head.html and add these Open Graph tags:


Copy
<head>
  ...
	<meta property="og:type" content="website" />
	<meta property="og:title" content="{{ site.page_title }}" />
	<meta name="og:site_name" content="{{ site.page_title }}" />
	<meta property="og:description" content="{{ site.app_description }}" />
	<meta property="og:image" content="{{ site.og_image }}" />
	<meta property="og:url" content="{{ site.canonical_url }}" />
 
	<meta name="twitter:creator" content="@{{ site.twitter_username }}" />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:image" content="{{ site.og_image }}" />
	<meta name="twitter:url" content="https://x.com/{{ site.twitter_username }}" />
</head>
You also need to add the canonical_url and og_image to the _config.yaml (these properties are not included in the template). Example:


Copy
canonical_url                             : https://fluttertips.dev
og_image                                  : https://fluttertips.dev/assets/social-media-banner.png
The example above assumes you’ll be publishing the landing page to a custom domain. If you’re not using a custom domain, you can use the GitHub Pages URL instead. More on this below.

6. Add website analytics (optional)
If you want to track traffic to your site, you can use a website analytics service such as Plausible by installing a tracking snippet that looks like this:


Copy
<script defer data-domain="yourdomain.com" src="https://plausible.io/js/script.js"></script>
This needs to be added inside _includes/head.html.

Once you’re done and your site is published, you’ll be able to see all the analytics data:

Website traffic for fluttertips.dev
For more info, read the Plausible docs, including how to add the tracking snippet to your website.

Plausible is my favorite web analytics platform. Other privacy-friendly alternatives to Google Analytics include: Simple Analytics, Fathom, and Matomo.

7. Test the Site Locally
To test the site locally, you need to have Ruby installed.

macOS
Linux

Copy
brew install ruby
If you’re on Windows and want to test the site locally, follow this guide: Jekyll on Windows.

Then, you can install Jekyll and serve the site locally:


Copy
bundle install
bundle exec jekyll serve
If all goes well, you’ll see something like this:

Output of bundle exec jekyll serve
By default, the site will be available here:

http://127.0.0.1:4000
Open this URL in your browser to preview the site.

8. Deploy to GitHub Pages
Once you’re done with the steps above, commit all your changes and push them to GitHub:


Copy
git add .
git commit -m "Landing page setup"
git push origin master
And thanks to GitHub Pages, your website can be deployed and go live in minutes.

We’ll see how to do that in the next lesson.

But first, time for a quick quiz!

Question 1 of 3
What can you customize in the landing page template?

App info and metadata in _config.yml

Images and screenshots

Privacy policy and terms as markdown files

Custom domain settings

Submit
Resources
Automatic App Landing Page
FontAwesome Icons (v5)
Unsplash (you can use this to find a header image for your site)
Plausible Analytics
Open Graph image size and best practices
GitHub Pages