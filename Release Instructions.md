Instructions for building and uploading Vienna binaries to Github and Sourceforge.

## One time setup step: ##

### Build settings
In Xcode->File->Project settings…, you should have :

- Derived Data : Default Location
- Advanced… : Build Location : Custom : Relative to Workspace
	- Products : Build/Products
	- Intermediates : Build/Intermediates.noindex

### CS-ID.xcconfig

To ensure that Deployment releases are properly codesigned, Xcode needs the `Scripts/Resources/CS-ID.xcconfig` file.

This file has been deliberately set to be ignored in our git repository, because its content should be personal to each developer. So you will have to create it, in order to define at least two environment variables:

`CODE_SIGN_IDENTITY`  
should be exactly the name of your certificate as it is stored in Keychain.

`PRIVATE_EDDSA_KEY_PATH`  
should be the location of the private EdDSA (ed25519) key used by Sparkle 2, which for obvious security reasons should not be located in the source directory !

`PRIVATE_KEY_PATH`  
should be the location of the (legacy) private DSA key used by Sparkle, which for obvious security reasons should not be located in the source directory !

If you want to go further in automation of package building, you will have to define three additional environment variables in the `CS-ID.xcconfig` file. These ones are used to automate the use of the `notarytool` command line tool as described in [this page of Apple's documentation](https://developer.apple.com/documentation/xcode/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow).

`APP_STORE_ID`  
is the Apple ID used to connect to App Store Connect

`KEYCHAIN_PROFILE`  
is the key to an app-specific password created for `notarytool` and stored through `xcrun notarytool store-credentials …`

`TEAM_ID`  
is the appropriate developer team identifier. It is generally a 10-character code. You can look-up the teams you are part of in the “Membership” area of [Apple's developer portal](https://developer.apple.com/account/).

For instance, the content of my `Scripts/Resources/CS-ID.xcconfig` file looks like this :


    CODE_SIGN_IDENTITY = Developer ID Application: Barijaona Ramaholimihaso
    PRIVATE_EDDSA_KEY_PATH = $(SRCROOT)/../secrets/vienna_private_eddsa_key.pem
    PRIVATE_KEY_PATH = $(SRCROOT)/../secrets/vienna_private_key.pem
    APP_STORE_ID = barijaona@mac.com
    KEYCHAIN_PROFILE = AC_PASSWORD
    TEAM_ID = KUU2LM7U9K

__Note:__ Vienna maintainers can [contact me](https://github.com/barijaona "Github") to get provisioning profiles for the above mentioned Team ID, in order to decentralize the distribution of Vienna's official builds.

## Tag Formatting ##

Tags should be in one of the following formats:

 -	Normal release: (3.0.0)

		v/3.0.0

 -	Beta release (Second beta for 3.0.0)

		v/3.0.0_beta2

 -	Release candidate (first for 3.0.0)

		v/3.0.0_rc1

## Steps before releasing Vienna: ##

 1.	Review all recent code changes and make sure you should not change `MACOSX_DEPLOYMENT_TARGET` in the project configuration in order to protect users whose machines do not match minimum macOS requirements from a counter-productive "upgrade".
 2.	Make sure that the "CHANGES" file is up to date.
 3.	Copy the most recent part of "CHANGES" in a new text document and process it with Markdown to get a new "notes.html".
 4.	Commit anything unstaged (on `master` branch if you are releasing a beta or on `stable` branch if you are doing a normal release).
 5.	Make a new tag using `git tag -s` _tagname_, respecting the above mentioned convention (if you do not have a gpg key, you can use `git tag -a` instead).

## Steps for preparing the package to be uploaded: ##

There are two distinct ways to get the different files needed to publish an update: a semi-automated way with Xcode, a fully automated way through the command line.

### Building with Xcode

- Make sure the "Vienna" scheme is selected at the top of Xcode's main window,
- Select the "Product->Archive" menu item,
- The Organizer window should open after a while,
- Select the latest archive, click the "Distribute App" button,
- Select "Developer ID" as method of distribution,
- Accept the values proposed in the following prompts,
- Wait for the upload to finish, then the message informing you that the software was successfully notarized,
- Close the organizer, select scheme "Deployment" at the top of Xcode's main window,
- Run the Deployment scheme,
- The Uploads window should open in the Finder after a while.

### Building through the command line

- If you have multiple versions of Xcode installed on your machine, ensure that an adequate version is selected. For instance, you might have to type `sudo xcode-select --switch /Applications/Xcode-beta.app` at the command line
- At the command line, run `make release`
- You will have enough time to take a tea, walk the dog or read your mails…
- At the end of the process, the Uploads window should open in the Finder,
- Check the last messages in the terminal. You should have something like `** EXPORT SUCCEEDED **` and `** BUILD SUCCEEDED **`.

## Steps to upload the release to the web ##

 1.	Push the tag to ViennaRSS' repository at Github (`git push --tags ViennaRSS master` or `git push --tags ViennaRSS stable`, accordingly).
 2.	Upload the contents of `build/Uploads` using the following steps.
  (Note: I'm using Vienna 3.3.0_beta4, 3.3.0_rc1 and 3.3.0 as examples here.)

### On Github:

   1. Go to Vienna's releases page on Github : <https://github.com/ViennaRSS/vienna-rss/releases>
   2. Choose "Draft a new release", type the tag name (`v/3.3.0_beta4`), a description ("Vienna 3.3.0 Beta 4").
   3. Upload the `Vienna3.3.0_beta4.tgz` file (if you use drag and drop, make sure to drop it on the "<i>Attach binaries by dropping them here or selecting them</i>" area and not on the text area).
   4. Upload also the compressed dSYM file (whose nome should be something similar to `Vienna3.3.0_beta4.5b272a6-dSYM.tgz`)
   5. For beta and release candidates, check the "This is a prerelease" box.
   6. Click the "Publish" button.
   7. Verify the uploaded app: download it, uncompress it and check that it runs OK.

### On Sourceforge.net:

   12. Check that the SourceForge Downloads page for Vienna at <https://sourceforge.net/projects/vienna-rss/files/> got the new files.
   13. For stable releases only : from the Sourceforge site, choose the ℹ️ button ("View details") of "Vienna3.3.0.tgz" (be careful to select the binary and not the code source file or the dSYM file!) and set the file as default download for Mac OS X. Don't do this for beta releases!

### On viennarss.github.io

   14. Upload `changelog_beta.xml` (or `changelog_rc.xml` or `changelog.xml` accordingly) and the `noteson3.3.0_beta4.html` file in the sparkle_files directory
   15. If you upload a release candidate, change `changelog_beta.xml` to be a copy of the new `changelog_rc.xml` ; and if you upload a release, change `changelog_rc.xml` to be a copy of the new `changelog.xml`
   16. Run the previous version of Vienna, and make sure that the Sparkle update mechanism works correctly to display and download the latest version. After updating, check again to make sure Sparkle is showing that you have the latest version.

### On Brew Cask

17. __Optional and for stable releases only :__ submit the version to Homebrew Casks with a command similar to this one:

````bash
brew bump-cask-pr vienna --version=3.3.0
````

Finally, consider posting an announcement of the new release on the CocoaForge Vienna forum at <http://forums.cocoaforge.com/viewforum.php?f=18> and/or <http://vienna-rss.com>.
