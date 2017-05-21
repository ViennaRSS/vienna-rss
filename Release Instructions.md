Instructions for building and uploading Vienna binaries to Sourceforge

## One time setup step: ##

 -	To ensure that releases are properly codesigned make sure that you have properly edited `configs/CS-ID.xcconfig` for your setup.
    CODE_SIGN_IDENTITY should be the name of your certificate as it is stored in Keychain,
    PRIVATE_KEY_PATH should be the location of the private DSA key used by Sparkle,
    CODE_SIGN_REQUIREMENTS_PATH should generally remain at its default value.

## Tag Formatting ##

Tags should be in one of the following formats:

 -	Normal release: (3.0.0)

		v/3.0.0

 -	Beta release (Second beta for 3.0.0)

		v/3.0.0_beta2

 -	Release candidate (first for 3.0.0)

		v/3.0.0_rc1

## Steps to release Vienna: ##

 1.	Review all recent code changes and make sure you should not change `MACOSX_DEPLOYMENT_TARGET` in "Configs/Project-All.xcconfig" in order to protect users whose machines do not match minimum OS X requirements from a counter-productive "upgrade".
 2.	Make sure that the "CHANGES" file is up to date.
 3.	Copy the most recent part of "CHANGES" in a new text document and process it with Markdown to get a new "notes.html".
 4.	Commit anything unstaged
 5.	Make a new tag using `git tag -s` _tagname_, respecting the above mentioned convention (if you do not have a gpg key, you can use `git tag -a` instead).
 6.	Run `make clean`.
 7.	Run `make release`. Check the last displayed messages to ensure yourself that the application is correctly signed.
 8.	Push the tag to ViennaRSS' master at Github (`git push --tags ViennaRSS master`).
 9.	Upload the contents of `Deployment/Uploads` (found in the build directory) using the following steps.
  (Note: I'm using Vienna 3.2.0_beta4, 3.2.0_rc1 and 3.2.0 as examples here.)

### On Github:

   1. Go to Vienna's releases page on Github : <https://github.com/ViennaRSS/vienna-rss/releases>
   2. Choose "Draft a new release", type the tag name (`v/3.2.0_beta4`), a description ("Vienna 3.2.0 Beta 4"). Upload the `Vienna3.2.0_beta4.tar.gz` file.
   3. For beta and release candidates, check the "This is a prerelease" box.
   4. Click the "Publish" button.

### On Bintray.com:

   5. Log in and go to <https://bintray.com/viennarss/vienna-rss/vienna-rss/view>
   6. Choose "New version".
   7. Fill the name ("3.2.0Beta4"), the description from the version notes, then click "Create version". Add the VCS tag (`v/3.2.0_beta4`) and update.
   8. Check the version (at <https://bintray.com/viennarss/vienna-rss/vienna-rss/3.2.0Beta4/view>), click "Upload Files" to go to <https://bintray.com/viennarss/vienna-rss/vienna-rss/3.2.0Beta4/upload> and upload the two .tar.gz files (whose name should be like `Vienna3.2.0_beta4.tar.gz` and `Vienna3.2.0_beta4.5b272a6-dSYM.tar.gz`).
   9. Click "Save the changes", then click "Publish".
   10. Go back to the files list (<https://bintray.com/viennarss/vienna-rss/vienna-rss/3.2.0Beta4/#files>), select the binary ("Vienna3.2.0_beta4.tar.gz") and choose "Show in download list" in the contextual menu.

### On Sourceforge.net:

   11. Check your email and verify that you have a message from Sourceforge stating "GitHub Downloads Import Complete".
   12. Verify the downloads. Load the SourceForge Downloads page for Vienna at <https://sourceforge.net/projects/vienna-rss/files/>, download new zip files, uncompress them, and run the apps.
   13. For stable releases only : from the Sourceforge site, edit the "Properties" of "Vienna3.2.0.tar.gz" and set it as default download for macOS. Don't do this for beta releases!

### On viennarss.github.io

   14. Upload `changelog_beta.xml` (or `changelog_rc.xml` or `changelog.xml` accordingly) and the `noteson3.2.0_beta4.html` file in the sparkle_files directory
   15. If you upload a release candidate, change changelog_beta.xml to be a copy of the new changelog_rc.xml ; and if you upload a release, change changelog_rc.xml to be a copy of the new changelog.xml
   16. Run the previous version of Vienna, and make sure that the Sparkle update mechanism works correctly to display and download the latest version. After updating, check again to make sure Sparkle is showing that you have the latest version.

### On Brew Cask

17. __For stable releases only :__ follow the steps listed below, adapted from the [Brew Cask Wiki](https://github.com/caskroom/homebrew-cask/blob/master/CONTRIBUTING.md#updating-a-cask):

>We have a [script](https://github.com/vitorgalvao/tiny-scripts/blob/master/cask-repair) that will ask for the new version number, and take care of updating the Cask file and submitting a pull request to homebrew-cask:

```bash
# install and setup script - only needed once
brew install vitorgalvao/tiny-scripts/cask-repair
cask-repair --help

# fork homebrew-cask to your account - only needed once
cd "$(brew --repository)/Library/Taps/caskroom/homebrew-cask/Casks"
git config --local hub.protocol ssh
hub fork

# use to update <outdated_cask>
outdated_cask='vienna'
github_user='your_github_username'
cd "$(brew --repository)/Library/Taps/caskroom/homebrew-cask/Casks"
cask-repair --pull origin --push $github_user $outdated_cask
```

Finally, consider posting an announcement of the new release on the CocoaForge Vienna forum at <http://forums.cocoaforge.com/viewforum.php?f=18> and/or <http://vienna-rss.com>.
