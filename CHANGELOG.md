Vienna ChangeLog File
=====================

Vienna 3.10.0
--------------
_released 2026-02-13_
### 🚲 Changes
- Add keywords for Spotlight search
- Replace some toolbar icons with symbols having a higher resolution
- Update translations
### 🤷🏻 Bugfix
- Fix enclosure detection in OPDS acquisition feeds
### ⚙️ Internals improvements
- Optimize asynchronous articles refresh
- Improve handling of "Check for Updates" menu item
- Remove a documentation file from bundle resources
### 🛤️ Infrastructure updates
- Build on macOS 26.3 / Xcode 26.2

Vienna 3.10.0 Beta 7
--------------------
_released 2026-02-09_

### 🚲 Changes
- Add a command to reopen the last closed tab
- Add a button to access notifications settings from Vienna's settings
- Disable "Subscribe in Open Reader" option when syncing is not yet configured
- Visual adaptations to macOS 26 (app icon, window corners)
- Remove deprecated Pocket plugin
- Update translations
### 🤷🏻 Bugfix
- Fix icons not being visible in table header on macOS 26
- Fix text-only mode of toolbar not working on macOS 15+
- Improve detection and repair of inconsistent counts of unread articles
- Fix relative URLs for certain feeds
### ⚙️ Internals improvement
- Have article controller fetch articles asynchronously
- Refactor feed discovery
- Remove legacy address bar
- Improve size limits for split views involving web view
- Clean up imports and class forward declaration
- Rename multiple variables/constants for consistency
### 🛤️ Infrastructure updates
- Update FMDB to version 2.7.12, Sparkle to version 3.8.0
- Build on macOS 26.2 / Xcode 26.2
- Update Github checkout action to version 6
- Update SwiftLint settings
### 📖 Documentation
- Add documentation about usage of large language models (so-called "AI")

Vienna 3.10.0 Beta 6
--------------------
_released 2025-09-05_

### 🚲 Changes
- Support closing tabs by clicking the middle button of the mouse
- Change application icon to conform to style of macOS 11 and later
- Change position of filter bar in vertical layout
- Suspend (up to 5 minutes) connection attempts when the computer is disconnected from network
- Use green double dot instead of yellow sparkle as mark of revised articles in article list
- Be more tolerant with feeds using RSS tags instead of Atom tags (or vice-versa)
### 🤷🏻 Bugfix
- Fix colors when a cell is selected and right clicked in article list 
- Respect the high contrast accessibility setting for bottom line 
- Add missing separator to filter submenu in main menu
- Fix / improve validation for some menu / toolbar items
- Fix crash or inability to parse caused by some feeds containing HTML tags instead of their XHTML equivalents
### ⚙️ Internals improvement
- Refactor filter bar into its own view controller
- Move several actions from AppController to ArticleController; rename many actions; remove unused methods from BaseView protocol
- Use storyboard for activity window and NewSubscription
- Remove deprecated network calls
- Reorganize classes related to article list in Xcode layout
- Fix definition & handling of ArticleStatusUpdated
- Minor fix in Changelog regarding versions 2.6.0

Vienna 3.10.0 Beta 5
--------------------
_released 2025-07-20_

___This is a [20th anniversary edition](https://www.vienna-rss.com/blog/news/2025/07/07/Celebrating-20-years-of-ViennaRSS.html)!___
### 🚲 Changes
- Distribute Vienna in _.dmg_ disk images instead of _.tgz_ archives
- Use Command-Control-0 to Command-Control-2 shortcuts for layout selection (these replace Control+Number shortcuts which are reserved)
- Update some translations (Traditional Chinese, Swedish, Danish, Dutch)
- Modify article view in Unified layout to be borderless
- Disable back/forward navigation in main tab's article web views
### 🤷🏻 Bugfix
- Fix crashes and other potential problems caused by folder cache being emptied during refresh
- Work around incorrect support of palette-color icons by newer macOS versions (15 and +); reorganize the code used for fetching and caching websites' favicons
### ⚙️ Internals improvement
- Rebalance AppController role:
    - move parts of the layout code to ArticleController
    - modify handling of keyboard events to avoid doing everything in AppController
    - diminish ArticleListView and UnifiedDisplayView reliance on AppController
    - move Sparkle Updater controller to ViennaApp
- Use an Application.storyboard as the starting point in "Interface Builder" for the design and the main menu; connect Preferences and Downloads storyboards to it.
- Remove ExtendedTableViewDelegate in favor of NSMenuDelegate
- Remove NSKeyedArchiver/NSKeyedUnarchiver methods which were needed for macOS 10.12 backwards compatibility
- Remove unnecessary debugging code using some private properties of WKWebView
### 🛤️ Infrastructure updates
- Simplify our version of Autorevision
- Clarify the directories used for derived files during build process

Vienna 3.10.0 Beta 4
--------------------
_released 2025-06-24_

### 🚲 Changes
- Register Vienna as being able to open OPML files,  e.g. in "Open With" menus
- Display details about failures on parsing feed in activity window
- Update link underline color to match system link color
- Trim whitespaces at start or end of folder names entered by user
### 🤷🏻 Bugfix
- Fix start and end of spinner animation informing of feed refreshes (bug introduced in 3.10.0 Beta 1)
### ⚙️ Internals improvement
- Refactor Download Window and its contextual menus
-  Resolve warnings in Xcode 26 beta
- Update document type declarations in Info.plist
- Declare some Objective-C designated initializers

Vienna 3.10.0 Beta 3
--------------------
_released 2025-06-12_

### 🚲 Changes
- Make search plug-in names in toolbar more explicit
### 🤷🏻 Bugfix
- Fix some freezes by blocking attempts to detect RSS in main tab
- Make tests about folders in smart folders more robust
- Fix non working setting for minimum font size
### ⚙️ Internals improvement
- Use find(_:configuration:completionHandler:) for searching in WKWebView in macOS 11.0+
### 🛤️ Infrastructure updates
- Update GitHub Action for Xcode 16.4

Vienna 3.10.0 Beta 2
--------------------
_released 2025-06-06_

### 🚲 Changes
- Replace Twitter plugin with X plugin
- Remove deprecated Google Currents plugin
### 🤷🏻 Bugfix
- Fix search of plugins on case-sensitive file systems
- Fix search plugins
- Fix animation bug when collapsing/expanding groups in folder list sidebar
- Fix bug that caused an invalid (duplicate) folder name being displayed while it has been rejected by the app
### ⚙️ Internals improvement
- Remove superfluous web view which might create problems
- Change BrowserTab initializers
- Resolve analyser warning about DownloadManager
- Optimize database before closing the app
### 🛤️ Infrastructure updates
- Build with Xcode 16.4
- Fix xcodebuild "fatal error" message in Github test pipeline log

Vienna 3.10.0 Beta 1
--------------------
_released 2025-05-25_

### 🚲 Changes
- Add a Mastodon plugin (based on AppleScript) :  configuration can be modified by holding down the Option key when invoking the plugin 
- Multiple improvements and fixes to AppleScript support
- Overhaul plugin manager with NSBundle instances to enable plugins localization
- Convert RSS feed sources to plugins
- Convert templates of OpenReader services to plugins
- Update URLs in plugins and default feeds; use https (instead of http) wherever possible
- Enable Vienna style templates to include a specific tag ($ArticlePublicationDate$) to support the display of article publication dates
- Improve the behavior of the font selection panel
- Group file download notifications in Notification Center
- Display latest downloads at the top of the download window
- Mimic Safari for web browser's user agent
- Update documentation and translations
### 🤷🏻 Bugfix
- Fix date 1.1.1970 or 31.12.1969 appearing for "Last Update"
- Fix "open with" menu in download window
- Prevent some of the situations which led Vienna to reset its folder order to alphabetical order
- Fix discrepancy in HTTP user-agent when adding a new subscription
- Remove obsolete sources of RSS feeds
### ⚙️ Internals improvement
- Refactor Article's properties and accessors
- Improve cache management for feed articles
- Improve error handling in OpenReader
- Optimize notifications number and timing during feed refreshes
- Improve lookup/selection of the "Unread Articles" smart folder
- Use view-based table view in download window
- Make handling and retention of font selection more robust
### 🛤️ Infrastructure updates
- Build with Xcode 16.3
- Add Crowdin CLI configuration for translations management
- Update tests

Vienna 3.9.5
-----
_released 2024-12-09_

### 🚲 Changes
- Search `<item>` elements under feed's `<rss>` element if they are not found under `<channel>`
- Improve handling of Media RSS specification in feeds: `<media:thumbnail>` may be used as a workaround for enclosures
- Update localizations
### 🤷🏻 Bugfix
- Extend fixes for "Last update" dates being set to January 1st, 1970
- Fix handling of `mailto:` URLs
- Fix handling of links specifying `target="_blank"`
- Work around situations with inconsistent unread counts
### ⚙️ Internals improvement
- Revert some of the changes in memory management introduced in version 3.9.3 (caching of folder's articles)
- Include a database update to fix entries that had January 1st, 1970 as the last update date
### 🛤️ Infrastructure updates
- Test build with Xcode 16.1 (macOS 15) and Xcode 15.4 (macOS 14)

Vienna 3.9.4
-----
_released 2024-10-27_

### 🤷🏻 Bugfix
- Prevent deleted articles from reappearing in feeds after refresh
- Prevent "Date published" and "Last update" dates from being set to January 1st, 1970
### ⚙️ Internals improvement
- Include a database update to fix entries that had January 1st, 1970 as the last update date

Vienna 3.9.3
-----
_released 2024-10-12_

### 🚲 Changes
- Distinguish "Date published" and "Last update" dates for articles.  
  This distinction can be used to define sort order or in smart folders definitions. To keep things simple and tidy, the "Date Published" information has not been added to the vertical layout.
- Change application category from "utilities" to "news"
### 🤷🏻 Bugfixes
- Fix text entry in the main tab's article view when the "Use Web Page for Articles" option is enabled
- Make command-click on a link open a new tab with this link
- Make option-click on a link open it in the browser which is not set as the default in General settings (either it is the system's default browser or Vienna's internal browser)
- Fix "Validate Feed" button in Info window when the feed has a query-based URL
### ⚙️ Internals improvements
- Make finding Vienna related content in help menus easier
- Improve recovery mechanism when Vienna is forced to switch to alphabetical sort for folders and feeds.  
  Hopefully, this should limit the risk of seeing the problem reoccur.
- Update informations related to folder even when the feed has no articles
- Make "Last Updated" date displayed in "Info" window more consistent
- Improve memory management (cache of folder's articles)
### 🛤️ Infrastructure updates
- Build with Xcode 16 and macOS 15 SDK
- Update to latest version of GitHub actions
- Use Crowdin.com for localizing content of HTML help files
- Enhance ChangeLog

3.9.2
-----
_released 2024-08-15_

- Change mechanism preventing Vienna from unexpectedly switching to alphabetical sorting of folders and feeds. This
  phenomenon might still occur but should be much more unlikely
- Perform a sanity check of database at launch
- Do not show warning sign on feeds without articles
- Fix crash when server sends unusual MIMEType
- Fix various issues in General Preferences window
- Fix autolayout issues which could unexpectedly resize the article view or the main window, or hide the enclosure view
- Fix style change to give immediate visual feedback
- Improve parsing of RSS content:encoded element
- For Unified layout, move the tip about the hovered link's URL at the bottom of the view
- Use String Catalogs (.xcstrings) for most translations
- Add more translations
- Update some documentation files

3.9.1
-----
_released 2024-07-06_

- Prevent Vienna from unexpectedly switching to alphabetical sorting of folders and feeds
- Prevent feed refreshes from causing unexpected changes of articles selection and interruptions of user's reading experience
- Fix and standardize the visual feedback for articles being marked as read (especially when the selection is a smart folder)
- Fix use of delete key to delete the current article when the focus is on the article view
- Fix use of up/down keys to navigate to previous/next article when the focus is on the article view
- Fix some issues with cache of folder's articles
- Fix URL cache management
- Fix small parts of French and Dutch translations
- Add credit to Ricardo Pinho for Portuguese translation
- Build with Xcode 15.4 (macoOS 14.5 SDK)
- Fix Xcode and SwiftLint warnings; prepare to Swift 6
- Use generated asset symbols for designating images and colours
- Update MMTabBarView to v/1.5.3
- Remove unused code
- Improve build process
- Update GitHub Action for macOS 14

3.9.0
-----
_released 2024-01-20_

- Rearrange some menu items in a more logical way
- Have auxiliary windows (Downloads, Activity Window, Info) stay on Vienna's main space
- Fix "mark all read" for folders containing multiple smart folders
- Fix behavior of some menu commands (Command-Y, Reload Page)
- Update documentation and default feeds to refer to Github discussions instead of the now defunct Cocoaforge forums
- Update localizations
- Update FMDB to version 2.7.8, Sparkle to 2.5.2, MMTabBarView to v/1.5.2
- Build with Xcode 15.2 (macOS 14.2 SDK)

3.9.0 Beta 1
------------
_released 2023-07-09_

### ! Requires macOS 10.13 or higher !
- New editor for smart folders: criterias can now be imbricated, allowing more complex and refined selections
- Add initial JSON Feed support
- Implement Apple's standard interface for sharing articles or pages; Vienna's traditional plugins do not appear in default toolbar, but are still fully supported and can be added or removed as preferred. 
- Unified search: a single search field can be used for searching within articles, current webpage, folders list or the web.
- Complete transition to WkWebView based browser; reimplement printing and download, improve contextual menus; fix Web Inspector (macOS >= 13.3)
- Use view-based cells for tree view of folders and feeds; font is no longer selectable, but user can choose between three cell sizes
- Fix compliance with refresh frequency set by user
- Fix disappearance of tooltips on refresh
- Code cleanup and modernization; built with macOS 13.3 SDK
- Update Sparkle to version 2.4.2, MMTabBarView to v/1.5.0

Known issue: due to some changes in preferences file format, you may have to reset sorting of folders and articles to your liking.

3.8.8
-----
_released 2023-07-09_

- Fix access to list of keyboard shortcuts in helpbook on macOS Ventura
- Adapt helpbook pages to dark mode
- Improve information on OpenReader
- Revert Sparkle to version 2.2.2 as a precaution

3.8.7
-----
_released 2023-04-16_

- Fix a long standing problem where OpenReader feeds read with another client would not be immediately synced in Vienna

3.8.6
-----
_released 2023-04-15_

- Fix Command-W behavior according to tab count: closes window when only main tab is present
- Fix memory leak when closing tab with the new browser
- Fix toolbar search field to only start search when the user presses the enter key
- Fix status text in window's status bar

3.8.5
-----
_released 2023-01-21_

- Fix "Previous Tab / Next Tab" menu commands to cycle between open tabs

3.8.4
-----
_released 2022-11-12_

- Add ability to hide/show the enclosure bar (through the View menu)
- Various OpenReader related improvements:
    - Better URL handling in Preferences / Settings window
    - Allow access over http or https (useful FreshRSS servers used in internal LAN)
    - When refreshing all folders, prevent same error dialog from popping repeatedly
    - Fix status discrepancies (especially persisting error icons)
- Fix width of left hand pane not being kept after application relaunch (on macOS Ventura)
- Modify details in Preferences / Settings window to better conform to the Human Interface Guidelines
- Modernize code : use newer APIs when available, prepare to sandboxing
- Update Sparkle to version 2.3.0
- Optimized for macOS Ventura : built with macOS 13 SDK (still compatible with macOS 10.12 and above)

3.8.3
-----
_released 2022-09-16_

- Fix "Open Link in New Tab" contextual menu item (on main tab when the new browser option is enabled)
- When the user uses the Space keyboard shortcut, keep the focus on the article list (as version 3.7.x did) to ease navigation with keyboard
- Fix a problem that could prevent decompression of the application on some configurations
- Improve various points of build process

3.8.2
-----
_released 2022-08-28_

- Fix loading of styles when the application is launched from a folder with special characters in its path
- Fix 'Back' / 'Forward' commands on main tab (items activation and management of queue)
- Update Italian localization
- Update Sparkle to version 2.2.1
- Silence some warnings

3.7.5
-----
_released 2022-08-28_

- Fix backtrack queue used for handling the 'Back' / 'Forward' commands on main tab

3.8.1
-----
_released 2022-08-16_

- Fix and improve display when "Use Web Page for Articles" option is enabled for a feed
- Fix link preview on legacy browser's article view
- Restore folder list width between app relaunches

3.8.0
-----
_released 2022-07-09_

- Add a disclosure triangle in feed credentials dialog, in order to provide additional feed details whenever it is needed to disambiguate the feed
- Remove "Empty Trash…" contextual menu command added in 3.8.0 Beta 3
- Fix a crash when trying to view a smart folder (problem introduced by 3.8.0 Beta 3)
- Fix toolbar's item validation problems when text-only mode is used on macOS 12
- Prevent white background from briefly appearing in article view while appearance is set to dark
- Optimize code, fix warnings
- Add a recommended ClangFormat configuration
- Update localizations
- Fix unwanted changes of toolbar mode (switches to text+icon while the user requested text-only)
- Remove floodmagazine.com from default feed list and update other URLs
- Update scripts building release binaries
- Update Sparkle to version 2.2.0

3.7.4
-----
_released 2022-07-09_

- Fix unwanted changes of toolbar mode (switches to text+icon while the user requested text-only)
- Remove floodmagazine.com from default feed list and update other URLs
- Fix scripts building release binaries

3.8.0 Beta 3
------------
_released 2022-05-15_

- Add "Empty Trash…" menu command to folder list's contextual menu
- Add a setting regarding emptying of trash in Preferences window
- Add "Actual Size" menu command for resetting text zoom
- Make text zoom menu commands work with new browser
- Fix copy of articles in article list
- Fix search method selection with new browser
- Add a warning in advanced preferences that enabling/disabling Javascript might, for systems prior to macOS 11, require a restart
- Add Australian and British English as localization variants
- Improve handling of asynchronous actions in new browser
- Use NSSecureCoding for encoding/decoding of database fields definitions, download list and some preferences
- Use NSAlert for emptying trash warning
- Replace deprecated methods
- Rename some constants, clean up code
- Update build architecture
- Update Sparkle to version 2.1

3.7.3
-----
_released 2022-05-15_

- Fix copy of articles in article list
- Update Sparkle to version 1.27.1

3.8.0 Beta 2
------------
_released 2021-10-17_

- Change minimum macOS requirement to 10.12 (Sierra)
- Speed up database handling (the updated database remains fully compatible with all 3.x.x versions of Vienna)
- When hovering over a link with new browser, display its address on a floating bar
- Add a hidden preference for always displaying the full date, not using relative dates like Today or Yesterday. This is enabled with the Terminal command: `defaults write uk.co.opencommunity.vienna2 DoesRelativeDateFormatting -bool NO` and can be reversed with `defaults delete uk.co.opencommunity.vienna2 DoesRelativeDateFormatting`
- Remove support for web plug-ins
- Respect new browser's preference setting regarding JavaScript (might require application restart)
- Fix download manager (old browser only at the time) and replace NSURLDownload with NSURLSessionDownloadTask
- Update AppleScript architecture (use definition files instead of suite/terminology files)
- Improve handling of URLs containing semicolon character in the path component
- Update Sparkle to version 2.0 beta 3 and add an EdDSA key
- Fix some application locks caused by new browser
- Fix some leaks with new browser
- Use Sourceforge for downloading binaries updates
- Replace older logging tools with os_log
- Silence many warnings
- Fix Github test action

3.7.2
-----
_released 2021-10-17_

- Speed up database handling (the updated database remains fully compatible with all 3.x.x versions of Vienna)
- Remove preference setting related to notifications (already handled by System Preferences)
- Fix image overflow with certain feeds
- Fix download manager and replace NSURLDownload with NSURLSessionDownloadTask
- Fix scripts handling in menubar
- Fix behavior when clicking on Dock icon
- Improve handling of URLs containing semicolon character in the path component
- Update Sparkle to version 1.27 and add an EdDSA key
- Update procedures for building binaries (use Sourceforge for binaries instead of Bintray, fix notarization and Github test action)

3.8.0 Beta 1
------------
_released 2021-08-27_

- Implement an experimental new browser based on WKWebView : it can be selected in Advanced preferences, and will be available after application restart. It is fastest and more secure.
- Refactor code:
    - modify ArticleController to be a NSViewController
    - structurate code around protocols like Browser, Tab, ArticleContentView, ArticleViewDelegate and BrowserContextMenuDelegate
    - change many methods of BaseView protocol to be optional and remove unneeded code
    - introduce new classes : ArticleConverter, ArticleStyleLoader, RSSSubscriber
- Remove preference setting related to notifications (already handled by System Preferences)
- Fix image overflow with certain feeds
- Fix scripts handling in menubar
- Fix behavior when clicking on Dock icon
- Update Sparkle to version 1.26
- Use NSFileManager properties for library paths
- Migrate some tests to Swift
- Update procedures for building binaries (don't use Bintray anymore, fix notarization)

3.7.1
-----
_released 2021-01-09_

- Improve autodiscovery of feeds inside webpages (among other improvements, detect URLs of feeds for YouTube channels or users)
- Fix wrong image used in article list to indicate existence of an enclosure
- Fix empty folders in build which interferes with plug-in loading

3.7.0
-----
_released 2020-12-31_

- Update database to enable auto-vacuum mode (the updated database remains compatible with older versions of Vienna)
- Add dark color scheme to Default and Serifim styles
- Fix search field for some macOS versions prior to macOS 11
- Fix database update on permanent HTTP redirections
- Fix a problem with some authentication challenges sent by servers
- Limit duration of requests to unresponding websites
- Modify symbols displayed in article list on macOS 11 Big Sur
- Update some localizations
- Update an URL in the default set of feeds
- Various code modernizations
- More coherent project settings
- Rearrange some files ; move images into a single Assets.xcassets folder
- Build with Xcode 12.3
- Improve SwiftLint settings

3.6.2
-----
_released 2020-12-06_

- Fix main window not appearing when "checking for new articles" preference is set to "Manually" 

3.6.1
-----
_released 2020-12-04_

- Fix brutal resizing of article view column in vertical layout
- Add ‘hidden’ preference to specify web user agent through command line : `defaults write uk.co.opencommunity.vienna2 UserAgentName <...>`
- Improve look of main window toolbar under macOS Big Sur
- Use adaptative grey for unread count in folders tree
- Update toolbar icons of preferences window
- Replace IOKit calls with NSBackgroundActivityScheduler for scheduling refreshes
- Address several deprecation warnings
- Refactor some methods from Objective-C to Swift (PopUpButton, AppController+Sparkle)
- Remove unused code and images, slightly reorganize project, move images and icons into assets catalog
- Handle gracefully when CS-ID.xcconfig file is missing
- Use Swift Package Manager instead of Carthage for managing dependencies (Sparkle, MMTabBarView v/1.4.12)
- Use Github Workflows instead of Travis CI for continuous integrations tests
- Update SwiftLint configuration

3.6.0
-----
_released 2020-11-12_

### ! 3.6 versions require OS X 10.11 (El Capitan) or later !
- Universal build (support Apple Silicon processors as well as Intel processors) through Xcode 12.2
- Refactor constants to be usable by Swift code
- Tweak DirectoryMonitor code
- Fix a warning
- Change configuration of handling of stale Github issues

3.6.0 Beta 5
------------
_released 2020-11-08_

- Silence some warnings
- Remove unused code
- Add GitHub workflow for testing

3.5.10
------
_released 2020-11-08_

- Fix application crashing on display of certain URLs (bug introduced by version 3.5.9) 
- Fix a crash when both expansion tooltip and progress animation were triggered
- Fix an annoyance with tooltip obscuring contextual menu in article list or folder list

3.6.0 Beta 4
------------
_released 2020-10-24_

- Update to Xcode 12

3.5.9
-----
_released 2020-10-24_

- Add toolbar icon for deleting articles
- Parse more tags from 'media' namespace to get YouTube descriptions
- Remove support of Bitly URL shortening in plugins
- Speed up the cleaning of URL strings
- Speed up parsing of date strings
- Prevent crash when parsing non XML data
- Fix empty ArticleView on returning to same article
- Update to MMTabBarView v/1.4.9
- Fix running individual Xcode tests

3.6.0 Beta 3
------------
_released 2020-10-04_

- Configure Github configuration to close abandoned issues

3.5.8
-----
_released 2020-10-04_

- Fix crash related to macOS Big Sur Beta
- Fix crash related to Xcode12 (update MMTabBarView to v/1.4.8)
- Fix tab bar to hide when a single tab is present
- More fix for inaccurate info on number of unread articles
- Fix to unread counts discrepancies on OpenReader feeds
- Avoid intempestive refreshes of article pane during feed refreshes
- Fix resetting of article pane when no article is selected anymore and "Use Web Pages for Articles" is enabled
- Fix Vienna Tests target

3.6.0 Beta 2
------------
_released 2020-09-08_

- Replace deprecated methods

3.5.7
-----
_released 2020-09-08_

- Fix file being hidden at end of "Download image"
- Fix crash on editing search folder
- Fix inaccurate information about number of unread articles
- Fix wrong behaviour of "Move articles to Trash: After a Month" preference
- Remove Google+ plugin ; replace it with Google Currents plugin
- Increase to 1000 the limit of articles fetched at once from an Open Reader feed
- Update Sparkle to v1.23.0 and MMTabBarView to v/1.4.7

3.6.0 Beta 1
------------
_released 2020-08-09_

### ! 3.6.x versions are for OS X 10.11 (El Capitan) or later only !
- Lift deployment target to macOS 10.11 & start modernizing code
- Replaced MASPreferences with Storyboard implementation (Preferences window)

3.5.6
-----
_released 2020-08-08_

- Vienna is now notarized (needed by macOS Catalina and later)
- Much improved OpenReader support :
    - sensibly decrease the number of network requests:
        - use single 'mark-all-as-read' requests for marking folders read
        - avoid requesting feeds which haven't been updated
   - work around a blockade put on by Inoreader
   - add ‘hidden’ preference to use specific AppId/AppKey with Inoreader:

       > Each user of Inoreader user is able to define (and monitor) a personal
       > set of AppId / AppKey values through Inoreader preferences located at
       > https://www.inoreader.com/all_articles#preferences-developer
       >
       > To have Vienna use these values instead of the default one, you have to
       > type in Terminal two commands similar to the following:
       >
       >>` defaults write uk.co.opencommunity.vienna2 SyncingAppId 9876543210`
       >>` defaults write uk.co.opencommunity.vienna2 SyncingAppKey JrS2smGyidtsxBOytDN1OWsSPcGURKWR`
       >
       > To get back to the default values:
       >
       >>` defaults delete uk.co.opencommunity.vienna2 SyncingAppId`
       >>` defaults delete uk.co.opencommunity.vienna2 SyncingAppKey`

    - adapt to feed identifiers used by TheOldReader and FreshRSS (numerical Ids instead of URLs)
    - improve feed infos synchronisation between Vienna and servers (feed name, homepage, folder/label)
    - fix a problem with credential input in sync preferences panel
    - improve first authentication on OpenReader server
- Fix feed subscription button in browser view
- Fix some problems with enabling/disabling of menu items and toolbar items
- Trim author names in database
- Update address of ArsTechnica feed
- Update components (FMDB 2.7.7 through Swift Package Manager insted of Carthage, TRVSURLSessionOperation)
- Modernize code, localization & building tools

__Note__ : this version will upgrade the database ; but the newer version of the database remains fully compatible with all Vienna 3.x.x versions. So there is no reason to fear upgrading, or at least testing this 3.5.6 version.

3.5.5
-----
_released 2019-12-23_

- Fix sizes of cells in Unified view
- Fix our own RSS URL
- Fix multiple problems with input and encoding of OpenReader credentials
- fix selection of next unread article through spacebar when the article view is empty
- Update link templates for zh-Hant language
- Update Swift support to version 5
- Update to Xcode 11
- Update Sparkle version to 1.22
- Improve build system
- Replace deprecated routines
- Fix some problem with processing of localizable strings

__Note__ : this version will upgrade the database ; but the newer version of the database remains fully compatible with all Vienna 3.x.x versions. So there is no reason to fear upgrading, or at least testing this 3.5.5 version.

3.5.4
-----
_released 2019-02-10_

- Fix dialog sheet handling definition of smart folders with multiple criteria
- Use w3.org feed validator instead of feedvalidator.org
- Modify User-Agent header used for fetching feeds (fix problem with Oxford University Press)
- On macOS Mojave, fix authorization for plugins using AppleScript
- Fix 'Add to Safari Reading List' plugin regarding articles with empty body
- Some improvements to macOS Mojave's dark mode
- Make article list's progress indicators less prominent
- Trim unneeded whitespaces in URLs of new subscriptions
- Optimize builtin images (losslessly reduce size of PNG and JPEG)
- Replace deprecated SDK calls
- Make process and logs more verbose regarding OpenReader server login failures
- Update Swift support to version 4.2
- Optimize Info.plist
- Optimize build

3.5.3
-----
_released 2019-01-13_

- Fix crash with problematic feed
- Fix parsing of feeds without titles
- Use basic preemptive authentication to work around some servers which do not send 401 challenges
- Fix update of tabs color when window gains/loses focus
- Prevent Vienna from appearing among dedicated browser applications in System Preferences/General
- Fix usability problem with search box
- Add DuckDuckGo and Qwant among options for search box
- Fix Twitter option for search box
- Use https for searching
- Add support for dark mode to Credits
- Fix tooltips in folders tree
- Update Sparkle to 1.21.2, autorevision to 1.21

3.5.2
-----
_released 2018-12-15_

- Fix behavior when a Javascript attemps to close a tab
- Refactor browser pane / browser dependency
- Update Sparkle to 1.21.1

3.5.1
-----
_released 2018-12-02_

- Add ‘Open With’ submenu to contextual menu for items in Downloads window
- Allow ‘Open’ in Downloads window even when file is not yet fully downloaded (handy for audio files)
- Improve tabs' support of macOS Mojave's dark mode
- Fix fetching of feeds from OpenReader server
- Sync OpenReader feed names
- Fix feed unsubscribes and moves for TheOldReader
- Fix alignment of feed/folders names which are in Arabic
- Fix double escaping on feed title / description in OPML files
- Update development team in About box

3.5.0
-----
_released 2018-10-17_

- Fix dark mode for horizontal layout
- Improve support of Emoji characters (use CoreText to draw cells)

3.5.0 Release Candidate 1
-------------------------
_released 2018-10-10_

- Initial adaptations to macOS Mojave's dark mode (work in progress)
- Improve right to left support
- Improve tab bar management ; fix video which continued to play when last tab was closed
- Fix background color of selected folder on OS X 10.9
- Update FMDB to 2.7.5

3.5.0 Beta 1
------------
_released 2018-08-26_

- Modernize network access (replace ASIHTTPRequest with a wrapper above NSURLSession). Vienna's memory management is now exclusively based on Automatic Reference Counting.
- Fix an encoding issue in localizable strings

3.4.2
-----
_released 2018-07-24_

- Changed file extension for binaries upload to tar.gz (instead of .tgz) as Github's user interface got picky again

3.4.1
-----
- Fix crash on startup on Mac OS X 10.9 and 10.10

3.4.0
-----
_released 2018-07-14_

- Initial update for Xcode 10
- Update for SwiftLint 0.25.1
- Update Crowdin configuration for Brazilian Portuguese

3.4.0 Beta 1
------------
_released 2018-05-18_

- New article menu and keyboard shortcut (Command-Y) to get back to the main tab (articles list)
- New "Share With Pinboard" plugin
- Remove obsolete Cocoalicious plugin
- New lithuanian translation, contributed by Andrius Družinis-Vitkus
- Improved Czech, Simplified Chinese, Galician and Russian translations
- Fix a bug that prevented adding a feed in Simplified Chinese
- New framework for managing tabs (MMTabBarView instead of PSMTabBarControl)
- Use Carthage instead of Cocoapods to manage dependencies
- Project cleanup and reorganization

3.3.0
-----
_released 2018-04-01_

- Improve Ukrainian localization

3.3.0 Release Candidate 1
-------------------------
_released 2018-03-25_

- Fix a problem with Sparkle autoupdate

3.3.0 Beta 1
------------
_released 2018-03-10_

- Improve loading of tabs: on application re-open, load of each tab is delayed until the user selects it
- Change default download location to the macOS default one
- Fix bug where "Show in Finder" in Downloads window didn't work unless file was fully downloaded
- Update developer documentation & change tests configuration

3.2.1
-----
_released 2018-02-05_

- Fix a crash on parsing some XML files
- Fix current feed URL not being displayed on edition of a feed
- Updated translations (Danish, Spanish, German, Russian)

3.2.0
-----
_released 2018-01-27_

- Use .tgz file extension for downloadable archives of Vienna.app and .dSYM files

3.2.0 Release Candidate 1
-------------------------
_released 2018-01-25_

- Fix some OpenReader error handling
- Remove a tab bar animation introduced in 3.2.0 Beta 1
- Update copyright information

3.2.0 Beta 3
------------
_released 2018-01-07_

- Fix persistent tab bar at launch
- Update FMDB to 2.7.4

3.2.0 Beta 2
------------
_released 2017-12-18_

- Fix crashes on systems prior to Sierra

3.2.0 Beta 1
------------
_released 2017-12-17_

### ! For OS X 10.9 or later only !
- New toolbar icons
- Use default external application to view content of cached XML files
- Show acknowledgements in "About" panel
- Technical updates :
	- Converted NIBs to XIBs and to Auto Layout
	- Moved translation system to Base localization and Crowdin
	- Refactored some UI elements to separate XIB files
	- Refactorings (to KVO or delegate patterns, and conversion of various elements to properties)
	- Change OpenReader to use asynchronous requests
	- Update to Xcode 9
	- Conversion of code for some UI elements to Swift4
	- Replace CDEvents with Swift-based FSEvents implementation
	- Update autorevision to 1.20
	- Update Sparkle to 1.18.1
	- Update MASPreferences to 1.3.0
	- plus various housekeeping changes…

3.1.16
------
_released 2017-09-26_

- Fix article selection after an article is deleted from within the 'Unread Articles' folder
- Fix bugs related to multithreading
- Fix handling of impossibility of creating the database

3.1.15
------
_released 2017-09-17_

- Fix article list not scrolling to top when selecting a folder
- Fix 'Skip Folder' not selecting the first unread article in the next folder with unread articles

3.1.14
------
_released 2017-09-12_

- Fix article pane not updating on article deletion from the 'Unread Articles' folder

3.1.13
------
_released 2017-09-10_

- Fixes related to searching and smart folders
- Fix for selection of first article when jumping on next feed
- Better fix for unwanted reload of the article currently being read during sync

3.1.12
------
_released 2017-09-04_

- Fix crashes induced by some URLs
- Fix crash on macOS 10.13 High Sierra related to Activity window
- Fix unwanted reload of the article currently being read during sync
- Fix selection of current article on change of sort criterion/order
- Fix bug where Vienna doesn't quit when you press ‘Quit Vienna’ in the Database Upgrade window
- Truncate long text items with an ellipsis

3.1.11
------
_released 2017-07-08_

- Fix deleting article from smart folder or filtered folder
- Fix selection of last unread article with Next Unread command
- Update FMDB to 2.7.2

3.1.10
------
_released 2017-04-24_

- Fix access to Get Info window
- Fix CoreAnimation related problems

3.1.9
-----
_released 2017-03-23_

- Change the website to vienna-rss.com as the old domain name (vienna-rss.org) could not be renewed. Perform a minor database evolution to update this.
- Add a plug-in supporting wallabag.it
- Show acknowledgements in "About" dialog box
- Fix del.icio.us URL
- Fix an issue with icon
- Change status bar icons to scalable pdfs
- Remove textures in some windows, change some .nib to .xib
- Refactor things (window preferences code, delegates, organization of help files …)
- Modernize build architecture (Xcode 8.2, update pods)

3.1.8
-----
_released 2016-11-25_

- Fixed an External XML Entity (XXE) vulnerability which allowed servers to steal the content of files on the machine running Vienna
- Fix incorrect escaping of OPML export
- Fix font preferences not working
- Fix error on unread articles count with OpenReader feeds
- Fix articles' list during feed refreshes when the current selection is a smart or group folder 

3.1.7
-----
_released 2016-11-02_

- Fix incorrect escaping of some feeds

3.1.6
-----
_released 2016-10-31_

- Add support for delta feeds (RFC3229+feed)
- Database performance improvements
- Fix 'N' key to not scan fresher articles from same folder, except for smart folders
- Fix 'B' key to always go to first unread article
- Fix retrieving article text of some feeds
- Fix some macOS Sierra glitches
- Fix status message after tasks like marking OpenReader articles read
- Fixes to Danish and Russian translations, thanks to David Munch and Rinat Shaikhutdinov

3.1.6 Release Candidate 2
-------------------------
_released 2016-07-23_

- New set of default feeds, thanks to Jesse Claven and Ricky Morse
- Fix infinite loop on ‘Skip Folder’ command when no unread articles were left
- Fix relative URLs, like in images's `srcset` attributes
- New developer tests, thanks to György Tóth
- Code refactoring / cleanup

3.1.6 Release Candidate 1
-------------------------
_released 2016-07-16_

- When the user selects a folder, loading articles from database occurs on a separate thread
- Fix again the 'N' key not selecting last unread article or not wrapping to the first unread article
- Keep currently selected article on refresh of a group or smart folder
- Fix article selection in Unified layout
- Fix "Last Refresh filter"
- Fix an exception on opening the General preferences window
- Fix an assertion failure
- Code refactoring
- Reorganized tests

3.1.5
-----
_released 2016-06-20_

- Fix syncing with FeedHQ
- Avoid unwanted eviction from cache
- Fix enclosure “Open” button when the enclosure URL has a query part
- Ensures the article pane displays selected article when switching from Unified to Horizontal or Vertical layout

3.1.5 Release Candidate 2
-------------------------
_released 2016-06-08_

- Fix 'N' key breakage when a single unread article remained below current folder selection
- Fix 'N' key not wrapping to the first unread article under certain circumstances
- Force images to scale correctly
- Try to fix an assertion failure on balancing start/stop animations

3.1.5 Release Candidate 1
-------------------------
_released 2016-06-01_

- Fix visual issue on marking read all articles in a group folder
- Fix deleting articles from a group folder
- Fix restoring Open Reader article from Trash
- Fix back and forward in Horizontal and Vertical layouts (invoked by < and > keys)
- Fix sort indicator in Horizontal and Vertical layouts
- Scrolls to top of list when selecting a folder
- Fix a rare occurence of crash in Preferences folder

3.1.4
-----
_released 2016-05-25_

- Fix extreme slowness on marking a series of articles deleted
- Improve selection of next unread article and article list update
- Fix selection of default RSS reader application in preferences window
- In General preferences, use localized names for download folder and RSS readers' app names
- Fixed a problem preventing window from appearing at launch in certain settings

3.1.4 Release Candidate 2
-------------------------
_released 2016-05-17_

- Improved detection of feeds URL
- Align selection behavior on selecting or skipping folders with 3.0.9's
- Fix handling of some addresses in internal browser's address field
- Improved German translation

3.1.4 Release Candidate 1
-------------------------
_released 2016-05-08_

- Refactored code
- Make sure that unread / starred statuses are in sync between Vienna and the Open Reader server[^314-1]
- When opening current article in browser, respect what is set in user's preferences on marking it read
- Fix validation button of “New Group Folder…” dialog
- Fix features in Downloads and Activity windows
- Handle images directly embedded in HTML code
- Make sure we have a keyboard responder after switching layout
- Default folder sorting is manual
- Fix various crashes
- Other bugfixes

[^314-1]: If you have deleted articles, you might have to reset the unread / starred statuses of these older articles from the web interface of your Open Reader server.

3.1.3
-----
_released 2016-04-06_

- Fix some crashes
- Fix empty article list displayed by some feeds
- Prevent unwanted updates of user interface while refreshing Open Reader feeds
- E-mailing a link now occurs in foreground

3.1.2
-----
_released 2016-03-26_

- More crash fixes
- Fix Vienna forgetting current folder/feed after termination and relaunch
- Restore mechanism required by some plugins, especially "Add to Safari reading list" 
- Conversion to modern Ojective-C

3.1.1
-----
_released 2016-03-19_

- Fix some crashes
- Fix deadlocks on OS X 10.8
- Fix the sort functionality in Activity Window

3.1.0
-----
_released 2016-03-14_

- Add search field in subscriptions tree
- In Atom feeds, prefer the ‘content’ item over the ’summary’ one
- Fix articles reappearing in a feed after being marked for deletion
- Improved memory management
- Fix broken Download window features
- Security : update Sparkle autoupdate framework with latest version and use a secure URL
- Fix some crashes


3.1.0 Beta 5
------------
_released 2015-11-15_

- Keep order of folders and groups on OPML export

3.0.9
-----
_released 2015-11-08_

- Fix problem w/ subscribing to some feeds
- Improve handling of feeds having duplicate GUIDs
- Fix some styles to limit maximum image size
- Improve the ad blocking feature of the Feedlight styles
- If adding existing feed, focus it
- Better handling of legal/illegal characters in URL strings
- Fix enclosure download when the URL string contains a query
- Recognize a few more file extensions to be directly downloaded
- Fix some crashes

3.1.0 Beta 4
------------
_released 2015-09-20_

- Fix a crash
- Ensure current article remains visible when changing layout
- Display articles of any newly added folder
- Some code refactoring

3.1.0 Beta 3
------------
_released 2015-09-16_

- Improved handling of feeds having duplicate GUIDs
- Fixed rendering of feeds having XHTML bodies
- Handle feeds having illegal characters
- Allow concurrent drawings in unified layout
- Converted code to use Automatic Reference Count
- Improved cache mechanism for articles (using NSCache)
- Compiled with XCode 7 GM under OS X El Capitan GM

3.1.0 Beta 2
------------
_released 2015-08-17_

- Fix unwanted scrolls in Unified layout

3.1.0 Beta 1
------------
_released 2015-08-17_

### ! OS X 10.8 or better only !
- Replace our "in house" database queue with FMDatabaseQueue and reorganize access
- Use view based NSTableView for unified layout (instead of PXListView)
- Replace JSONKit with NSJSONSerialization
- Replace XMLParser with NSXMLDocument/NSXMLNode
- Replace other deprecated functions / Miscellaneous refactoring

3.0.8
-----
_released 2015-08-17_

- Fix unwanted scrolls in Unified layout

3.0.7
-----
_released 2015-08-17_

- More consistent response to keyboard shortcuts when the user switches to primary tab
- Add support for handling http/https (allows dragging links into Vienna's Dock icon)
- Change internal browser’s user agent string to be more Safari like
- Fix indexation problems in help files

3.0.6
-----
_released 2015-07-30_

- Fix a problem with duplicate folders when starting with a fresh database
- Removed macosxhints.com from the list of default feeds when starting with a fresh database
- Distribution of Vienna binaries is now done mainly through bintray.com instead of sourceforge.net

3.0.5
-----
_released 2015-07-22_

- Add identification of the application as required by Inoreader
- When encountering a 301 HTTP response code, check if the permanent character of the redirection is OK before updating the database
- Handle Enter or Return keys in Articles tab by opening the current article
- Add an option in Preferences to follow beta versions of Vienna updates

3.0.4
-----
_released 2015-03-01_

- Add option to enable/disable Webkit plugins (including Flash)
- Code reorganization : use of Cocoapod for dependancies

3.0.3
-----
_released 2015-01-18_

- Fix problems with preferences dialog on OS X < 10.10
- Fix small localization issues

3.0.2
-----
_released 2014-12-29_

- Handles dragging and dropping of .webloc files
- More accessible Preferences window
- Fix a synchronization issue with InoReader
- Various adaptations in development/building environment
- Fix various localization issues

3.0.1
-----
_released 2014-11-16_

- Fix a crash
- Parse RSS feeds having `rss:title`, `rss:link`, `rss:description`, `rss:items` and `rss:item` tags instead of the standard `title`, `link`, `description`, `items` and `item`
- Fix diverse localization issues

3.0.0
-----
_released 2014-11-02_

- New style : Classy (contributed by user PMP on cocoaforge)
- Fix some crashes when sharing a link on Google+
- Improved management of animations in folders list

3.0.0 Release Candidate 9
-------------------------
_released 2014-10-19_

- Fix repeating articles problem on some feeds with repeating GUIDs (notably Netflix)
- Fix some overly aggressive URL escaping
- Fix column order and dimensions not being remembered in article list
- Fix visual glitches with some feeds in article list

3.0.0 Release Candidate 8
-------------------------
_released 2014-10-11_

- Follow-up on crash : disable assertions for deployment config

3.0.0 Release Candidate 7
-------------------------
_released 2014-10-10_

- Fix a crash

3.0.0 Release Candidate 6
-------------------------
_released 2014-10-09_

- Handles multiple authors
- Adaptations for OS X Yosemite (10.10)
- Fixed some crashes
- Ask the user if she/he wants to send (anonymous) system configuration informations to Vienna developers
- Localization and help files improvements (English, French, Danish)
- Fixed a problem with video sounds still playing after the tab was closed
- Fixed panes dimensions inside the main window
- Changed code for subscribing, especially for subscription to local files
- Start implementing a test suite
- Built on OS X Yosemite SDK (for running, requirements are limited to OS X Snow Leopard or better)

3.0.0 Release Candidate 5
-------------------------
_released 2014-08-24_

- Improved stability
- Solves a bug where articles' read/unread situation was not currently reflected in the article list

3.0.0 Release Candidate 4
-------------------------
_released 2014-08-17_

- Fix another crash
- Improve localizations (including Spanish, thanks to Juan Pablo Atienza Martinez)
- Improved Unified layout

3.0.0 Release Candidate 3
-------------------------
_released 2014-08-08_

- Fix some crashes
- Remember chosen text size in article view
- Fix text vertical centering
- Add a "Share with Hootsuite" plugin
- Handle enclosures with filenames containing spaces or special characters
- Improved build process

3.0.0 Release Candidate 2
-------------------------
_released 2014-07-27_

- Background fetching and database writing of feeds (yes, such an important change is not expected between two release candidates versions, but the risk has been thoroughly pondered)
- Separated "Mark Read" and "Mark Unread" menu items for articles
- Rudimentary support of OPDS feeds (ebooks), like those provided by Calibre
- Fix an issue with number of unread articles caused by user deleting articles stored in OpenReader before having read them
- Spanish localization improvements, thanks to Juan Pablo Atienza Martinez
- Another fix for file:// URLs
- Fix relative links to enclosures
- Handle embedded images `<img src="data:..." ...>`
- Multiple improvements and fixes on memory management
- Other cosmetic or UI fixes

3.0.0 Release Candidate 1
-------------------------
_released 2014-04-30_

- Add The Old Reader (<https://theoldreader.com>) as a supported OpenReader provider
- Improved InoReader support (handles homepage and icons)
- Improved Unified layout
- Improved accessibility
- Improved German translation
- Fix credentials input for feeds requiring authentication
- Handle dates with a two-digit date formatter
- Fix some plugins
Thanks to Emiliano Necciari, Boris Dušek, bavarious and biphuhn for their contributions !

3.0.0 Beta 20
-------------
_released 2014-01-20_

- Largely improved Unified layout
- Added InoReader (<http://www.inoreader.com>) as a supported OpenReader provider, fix some OpenReader behaviors.
- Fix 'Feed->Unsubscribe' command with OpenReader feeds
- Handle requests by scripts/plugins to open new windows
- Fix problems with feeds from some servers
- Fix Vertical layout in situations where there is only a line per cell

3.0.0 Beta 19
-------------
_released 2013-11-27_

- Fix a crash which occured when deleting multiple articles under OS X Mavericks
- Improved Unified display view
- Triggers gzip compression with servers using Google Servlet Engine (ie Blogspot)
- Various Open Reader improvements
- The list of open tabs was sometimes lost after a crash
- Fix memory management problems
- Other bug fixes and code modernization

3.0.0 Beta 18
-------------
_released 2013-09-04_

- Improvement on Beta 17

3.0.0 Beta 17
-------------
_released 2013-09-04_

- Fix a serious problem with using the "Mark updated articles as new" preference

3.0.0 Beta 16
-------------
_released 2013-09-03_

- Fix autoupdate issue for users running 10.6

3.0.0 Beta 15
-------------
_released 2013-09-03_

__Mac OS Snow Leopard (10.6) or later only !!!__
- Improved speed thanks to a new database wrapper (contributed by echelon9 and barijaona)
- Fix many Unified display view problems
- Fix for some iframes/videos which did not show
- Improved string to date conversion routine (solves problems with some feeds which wrongly showed as updated)
- Fix some problems reported by analyser

3.0.0 Beta 14
-------------
_released 2013-08-18_

- Fixed a bug in sync password management (__Note__ : if you had connection problems with your Open Reader server, open Keychain Access and delete all Vienna-related elements. Then, reenter your credentials in Vienna).
- Added a Google Plus plugin
- Better handling of feeds containing linefeeds
- Better handling of feeds reusing the same GUID
- Changed handling of read/starred status for Open Reader feeds
- Changed handling of Unified layout

3.0.0 Beta 13
-------------
_released 2013-07-17_

Bugfixes :
- Open Reader server settings were often uncorrectly saved
- count of unread articles on Open Reader feeds was often incorrect
- fixed Undo for "mark all read/unread" and Open Reader feeds
- author names containing linefeeds weren't correctly displayed

3.0.0 Beta 12
-------------
_released 2013-07-13_

- Replaced Google Reader support with support of BazQux and FeedHQ (other services might work too, just give them a try !)
- Renamed our layouts : Horizontal, Vertical and Unified
- The Unified layout has been completely rewritten. It now allows selection of an article (right click or click in the left margin)) for sharing it or marking it.
- Vienna's integrated browser is now able to present the user a file selection dialog (for instance for uploading a file)
- Added a "Reindex Database" menu item
- Fix problems with icons in Leopard and Snow Leopard
- Visual tweaks and improvements
- Translation improvements (Brazilian Portuguese, Dutch, German, French, Korean)
- Many bugfixes

3.0.0 Beta 11
-------------
_released 2013-03-17_

- Fix a bug on preserving article currently being read on refreshes
- Updated Dutch translation
- Reviewed the localized versions of the "Get Info..." window, which were often mangled

3.0.0 Beta 10
-------------
_released 2013-03-14_

- New icons (thanks to Nick Dazé and romiq !)
- New themes (thanks to Nick Dazé and Carles Bellver)
- New plugin : Add to Safari reading list
- Two new filters : "Last 48 hours" and "Unread or flagged"
- New option to treat updated articles as new
- Updated Danish and German translations
- Bugfixes

3.0.0 Beta 9
------------
_released 2013-01-13_

- Refreshes should be quicker now (especially for Google Reader feeds)
- Better handling of some ill-formed feeds
- Videos aren't reset anymore when a feed refresh occurs
- Fix an issue related to opening articles' original webpages
- When defining a smart folder criteria, it is now possible to specify a Google Reader feed
- Code signature modified to be compatible with OS X 10.5
- Fix an error in German translation
- Small visual improvements
- Avoid warnings related to date string formats
- Improvements to the build process

3.0.0 Beta 8
------------
_released 2012-12-31_

- Fixes to the build process
- Fix date parsing
- Fix cookies issue with some feeds

3.0.0 Beta 7
------------
_released 2012-12-29_

- Reorganized on disk layout
- Reorganized build system and version numbering (thanks to dak180)
- Revised documentation (English and French)
- Revised German translation (thanks to biphuhn)
- Should be more safe for the database
- Fix issues with dates
- Fix some problems with layouts
- Fix problems with certain feeds

3.0b.2821
--------
_flagged 2012-11-18_

- Refreshes do not interfere anymore with user's reading experience
- Remember columns positions between relaunches
- New default style
- Add Instapaper and Pocket (ReadItLater) plugins
- Supports Apple's notification center (in addition to Growl for OS's prior to 10.8)
- Fix a problem with Google subscription list synchronization
- Ensures we get a Google token before performing some actions
- Correctly handle permanent redirects (HTTP response codes 301)
- 404 HTTP response status weren't correctly reported to the user
- Better handling of feeds containing HTML tags and/or entities and newlines
- Fix relative links in articles
- Greatly improved memory handling
- OPML export now includes Google Reader feeds
- When clicking a RSS link or the RSS button, take into account user's preference for subscribing (locally or on Google Reader)
- Other miscellaneous fixes

3.0b.2820
---------
_flagged 2012-09-23_

- When closing a tab, close its content
- Fix the "last refreshed" filter
- Fix parsing some date strings
- Enable commands "Get Info", "Unsubscribe", "Resubscribe" with Google Reader feeds
- If a feed is submitted through a button or a link, guess if it should be subscribed locally or on Google Reader

3.0b.2819
---------
_flagged 2012-09-07_

- Fix other nasty crashes on Mountain Lion

3.0b.2818
---------
_flagged 2012-09-02_

- Fix some nasty crashes on Mountain Lion which occurred when closing tabs
- Fix the "Check for newer versions of Vienna at startup" preference
- Make the knob of the vertical scrollbar more visible when reading long lists on Lion/Mountain Lion
- Other minor bugfixes and code cleaning

3.0b.2817
---------
_flagged 2012-08-25_

- Fix fetching of icons associated to feeds.
  *Note* : users of previous versions are invited to use the "Refresh Folder Images" menu item
- Better accessibility for people with visual impairment through VoiceOver
- Completely logout from Google Reader when the "Sync with Google Reader" preference is unchecked
- Builds are now signed with Developer IDs delivered by Apple, to meet Mountain Lion's Gatekeeper default requirements.

3.0b.2816
---------
_flagged 2012-07-26_

- Google Reader support ! Each feed can either be local (especially authenticated feeds, which are not handled by Google Reader), or hosted on Google Reader
- 64 bit support
- Full Screen support on Mac OSX Lion and Mountain Lion
- Fixes running on Leopard and on PowerPC
- Fixes feeds whose titles are XHTML or contain linefeeds/carriage returns
- Fixes Atom feeds with relative links
- Stay on Discrete Graphics mode on Macs having dual graphics cards
- Improved web browser experience (persistent cookies)
- Some functions which were only available on Report or Condensed layout are now available on Unified layout
- Increased timeout for feeds refresh
- Larger use of multi-threading
- Compiled with LLVM
- Binaries are now signed to avoid blockade by Mountain Lion's gatekeeper default settings (for first run, you'll have to right click and select 'Open')
- Many other bugfixes

2.6.0 (2601)
------------
_released 2011-12-18_
(2.6.0 Release Build, only released with i386 architecture)
- Added Buffer plugin

2.6.0 (2600)
------------
_released 2011-06-11_
(2.6.0 Test Build)
- Added Ascending and Descending items to the View > Sort By menu.
- Added support for ',' duplicating '<' and '.' duplicating '>' since they appear below them on many country's keyboard layouts and this helps avoid having to hit the shift key since most of the other keyboard shortcuts handle both upper and lower case.
- Added a feature to load the web page corresponding to a feed article instead of the text from the RSS feed. 
- Added a checkbox to the InfoWindow for the feeds to turn this feature on and off.
- Added a new class ProgressTextCell to draw a progress indicator while the web page is loading since this will no longer be instantaneous.
- Added menu items for Use Current Style for Articles and Use Web Page for Articles to make the new web page article feature more discoverable.
- Moved the folder-specific Get Info... and Unsubscribe to Feed menu items to the folder menu with the other folder-specific items.
- Fixed a bug where a folder's InfoWindow was not updating if you changed a flag via the menu item via the Unsubscribe or Use Web Page for Articles menu items.
- Added support for Open Page in Safari (Preferred Browser) and Copy Page Link to Clipboard context menu items for the new web-page based articles.
- Added a new single-key keyboard shortcut for the letter 'b' or 'B' that takes you to the beginning of the unread articles.
- Fixed a bug where the activity window detail text always listed a spurious HTTP Redirect for every single URL.
- Updated the Activity Window redirect logging to include the HTTP code for the redirect.
- Fixed bug where changes to the subscription in the InfoWindow were not saved when the window was closed.
- Fixed bug where edits to the subscription from the Folder menu were not reflected in open InfoWindows.
- Open Article Page now handles multiple selections both in the built-in browser and in the external browser. Articles opened are also automatically marked as read. Thanks to Jan for the code contribution.

 2.5.1 (2502)
-------------
_released 2011-06-11_
(2.5.1 Release Build)

- Fix issue where styles fail to render under Mac OSX Lion.
- Fix Share With Twitter plugin.

2.5.0 (2501)
------------
_released 2010-03-18_
(2.5.0 Release Build)

- User Interface refresh: Removed the grey headers, made the vertical divider easier to grab and made filtering more discoverable.
- Added support for plugins.
- Added support for search engine plugins and the ability to do web-searches from the toolbar.
- Added support for blog editor plugins.
- Added support for sharing plugins that work like bookmarklets for social websites.
- Added "Share With Facebook" button.
- Added "Share With Evernote" button.
- Added "Share With Twitter" button with automatic URL shortening via bit.ly.
- Added user contributed "Share with Delicious" plugin to the core distribution. Thanks to forum user czanderna.
- Update to the current version of Sparkle, which prevents auto-updating to a version of Vienna which will not run on the user's system.
- Fix bug where deleting a feed in Unified view mode would cause Vienna to stop working correctly.
- Fix bug where changing the article font size would crash Vienna.
- Fix bug that caused zombiefied update spinners (thanks to Curtis Faith).
- Fix bug that caused the reading position to be lost upon refresh (thanks to Curtis Faith).

2.4.0 (2401)
------------
_released 2010-01-13_
(2.4.0 Release Build)

- Fix the filter field article selection problem reported at http://forums.cocoaforge.com/viewtopic.php?f=18&t=21665
- Enable navigating the built-in browser's back/forward-list via  left/right three-finger swipes.
- Enable navigating feeds via left/right three-finger swipes: Left for "Go Back" and right for "View Next Unread".
- Enable as scrolling to the top/bottom of web pages and the article list via upwards/downwards three-finger swipes.
- Change "currentSelection" to "currentTextSelection" in Viennas Applescript terminology.

2.4.0.2400
----------
_released 2009-12-13_

- Remove command-shift-g as keyboard shortcut for creating group folder. This is now used for Find Previous.
- Show an alert when upgrading the database version, because it can take a while.
- Turn off animation of tab resizing. It was slow, superfluous and apparently sometimes caused drawing errors in the tab bar background.
- Fix crash when sorting articles by enclosure URL.
- Update SQLite to version 3.6.18.
- Add ability to "Show XML Source" for feeds, which is now cached locally.
- Add support for IDN (internationlized domain names) in the browser.
- Add new supported blog editor (Blogo).
- Increase the standard number of simultaneous refresh downloads to 20.
- Redo browser and filter bar UI. Slimmer look, new buttons.
- Vienna's UI now correctly dims when the application is the background.
- Enable printing of web-pages from the built-in browser.
- Vienna now shows an error page with useful information when the browser fails to load a resource.
- Fix bug where changing the layout would hide the tab bar until relaunch.
- Fix bug that prevented the user from searching for text within a web-page.
- Fix drawing errors and artifacts in the grey title bars.
- Check for https:// as well as http:// on the pasteboard when adding a new subscription.
- Fix background drawing errors in main window and remove custom window background.
- Fix drawing error in Downloads window and remove custom background.
- Fix bug and exception where clicking on a feed link launched Vienna but failed to subscribe to the feed.
- Add workaround for feeds that contain more than one item with the same guid. (For example, the WordPress Trac, to name the guilty.)
- Fix long standing bug where deleted articles would reappear after emptying the trash.
- Fix "Help -> Keyboard shortcuts", which didn't work at all.
- Numerous fixes to localization of help pages and other strings in German, French, and other languages.
- General code and build-phase cleanup, as well as minor speed improvements for some operations.
- Drop Mac OS X 10.4 Tiger support. Vienna 2.4 needs 10.5 Leopard or greater to launch.
- Prevent an infinite redirect loop. This was happening with http://feeds.feedburner.com/factcheck/Rdqt
- Fix the article view scrolling problem reported at http://forums.cocoaforge.com/viewtopic.php?f=18&t=20814
- Fix the mark all read bug on Snow Leopard reported at http://forums.cocoaforge.com/viewtopic.php?f=18&t=20877
- Eliminate deprecated method warnings on Snow Leopard.
- Eliminate drawing artifacts in Folders and Articles headers. (Patch from Dan Crosta)
- Fix a crash reported at http://forums.cocoaforge.com/viewtopic.php?f=18&t=21303

2.3.4 (2305)
------------
_released 2009-07-31_
(2.3.4 Release Build)

- Fix General Preferences pane crash when trying to set default RSS reader or Download folder. Sigh.

2.3.3 (2304)
------------
_released 2009-07-30_
(2.3.3 Release Build)

- Fix Preferences pane crash introduced in Vienna 2.3.2.

2.3.2 (2303)
------------
_released 2009-07-27_
(2.3.2 Release Build)

- SECURITY: fix potential vulnerability when deleting a maliciously crafted subscription. (Reported by Julien Bachmann)
- Fix for bug 2724576: If network is down, URL tab information is lost. (Patch from Benedict Cohen).
- Fix for bug 2381168: Keychain issues with https.
- When switching back and forth from a tab, maintain the selected user interface item in the tab.

2.3.1 (2302)
------------
_released 2008-11-17_
(2.3.1 Release Build)

- Fix crash on Tiger when customizing toolbar.

2.3.0 (2301)
------------
_released 2008-09-16_
(2.3.0 Release Build)

- Drop Mac OS X 10.3 Panther support. Vienna 2.3 needs 10.4 or greater to launch.
- Leopard fix: allow option-left-arrow and option-right-arrow as keyboard shortcuts for closing and opening group folders.
- Bug fix: when validating a URL, escape any special query characters.
- Fix assertion failure when the user enters an invalid URL string in the address bar.
- Fix bug with smart folders and German umlauts.


2.3.0.2300
----------
_released 2008-06-01_

WARNING: MAC OS X 10.3 PANTHER USERS SHOULD NOT DOWNLOAD THIS! IT WON'T RUN.

- Drop Mac OS X 10.3 Panther support. Vienna 2.3 needs 10.4 or greater to launch.
- Add folder ordering option (manually or by name).
- Improvement to Send Link for multiple links and escaped characters. (Patch from Anmol Khirbat).
- Change standard product URLs to the new www.vienna-rss.org web site.
- Bug fix: Truncated Headings in LA Times Feeds
- Bug fix: Unescaped HTML in titles.
- Bug fix: Incorrect document URL shown after downloads.
- Bug fix: Option-clicking the close tab widget closed the main Articles tab.
- Add Kaku http://ppmweb.lolipop.jp/apps/kaku to the list of supported blog editors.

2.2.2 (2212)
------------
_released 2007-12-24_
(2.2.2 Release Build)

- Fix cookie handling on Leopard. (This could cause crashes.)
- Fix error in Spanish translation. (Thanks to Ramon.)

2.2.2.2211
----------
_released 2007-12-10_

- Fix crash when web page attempts to open pop-under window.

2.2.1 (2210)
------------
_released 2007-12-02_
(2.2.1 Release Build)

- Fix appearance of search field in toolbar when using small size.
- Fix the visual glitch in which the unread count and progress indicator were slightly overlapping
  with the scroll bar if present.
- Update the styles menu in the toolbar when adding a style.
- Added Portuguese localisation. (Thanks to Rui Carlos A. Gon√ßalves).
- Added Turkish localisation. (Thanks to Emrah Omuris).
- Updated German, Italian, Traditional Chinese, and Ukranian localisations.
- Updated Spanish localisation (Thanks to Dani Carril).
- Fix feed parsing crash on PowerPC machines (Patch from Paul Livesey).
- Possible fix for crashes in ArticleController.
- Fix the truncated right pane in Leopard.
- Fix long-standing issue with many messages in console.log while downloading (Patch from Martin H√§cker).
- Add support for blogging with MarsEdit 2.

2.2.0 (2209)
------------
_released 2007-09-09_
(2.2.0 Release Build)

- More minor toolbar bug fixes.
- Updated toolbar button bitmaps.

2.2.0.2208
-----------
_released 2007-08-26_

- Fixed bug: ampersand in folder name broke smart folder criteria.
- Fix shrinking toolbar button bug.
- Fix problem where Vienna failed to launch under 10.3.9.

2.2.0.2207
----------
_released 2007-08-19_

- Add patch to pass selected text to blogging clients. (Contributed by Pukka author Justin R. Miller).
- Fix exception caused by misparsing author field in some Atom feed items.
- Fix "CGContextRestoreGState: invalid context" errors reported to the console log.

2.2.0.2206
----------
_released 2007-08-10_

- Updated German localisation.
- Fixed overpainting bug in Download window.

2.2.0.2205
----------
_released 2007-08-05_

- Allow the Search Results folder to be deleted.
- Fix memory leak.
- Minor toolbar button cleanup.

2.2.0.2204
----------
_released 2007-07-29_

- Fixed bug: on launch, filter popup didn't reflect filter setting.
- Make Refresh toolbar button toggle between refresh and cancel.
- Add Search panel for when the toolbar is turned off or the Search field is removed from the toolbar.
- Fix feed autodiscovery for servers that gzip content.

2.2.0.2203
----------
_released 2007-07-13_

- Updated all built-in styles to add enclosure field.
- Improved toolbar styles.
- Added Ukrainian localisation. (Thanks to Andrew Kachalo).
- Fixed toolbar UI corruption bug.
- Updated keyboard shortcuts in help file.
- Added Get Info and Style toolbar buttons.

2.2.0.2202
----------
_released 2007-07-03_

- Fix bug in 2201 which broke saving a new smart folder.
- Fix CGContext errors in the system console log caused by the Vienna tab control gradient background.
- Add Growl events for file download success and failure.
- Add filter bar to more easily filter the article list.
- Add global search bar.

2.2.0.2201
----------
_released 2007-06-24_

- UI improvements contributed by Philipp Antoni.
- Switched to polished metal style.
- Added Russian localization. (Thanks to Taras "sacrat" Brizitsky).
- Show refresh indicator in folder list next to feed currently being refreshed.
- Add unsubscribe/resubscribe command to File menu.
- Show enclosure pane below article for articles that contain enclosures.

2.2.0.2200
----------
_released 2007-05-28_

- Added ability to drop OPML files onto Vienna's dock icon.
- Added support for RSS/Atom enclosures.
- Add conditional support in templates.
- Overhauled UI.
- Added new standard style.
- Added more built-in styles.
- Command + T now opens new tab.
- Accept web pages as subscription URLs and parse to extract the feed.
- Show RSS button in browser if the web page links to an RSS feed. Clicking the button subscribes to that feed.
- New tab bar control. (Thanks to Evan Schoenberg).
- Add option to add Vienna to the system status bar.
- Added Basque localization. (Thanks to Aitor Zubizarreta).
- If Vienna doesn't handle the URL scheme (e.g., itms), open the URL with the default application for its scheme.
- Allow refreshing of unsubscribed feeds if they are specifically selected. (Thanks to ytrewq1 for submitting a patch.)
- Updated to SQLite 3.3.17.
- Change exported file format to UTF8. (Thanks to Kiyu Horiuti).
- Added toolbar and moved buttons to toolbar. (Thanks to David Kocher for the prototyping).
- Added support for toggle status bar and moved progress indicator to toolbar.
- Add toolbar button to empty the trash.
- Added flagged article filter.
- Refresh all subscriptions now refreshes in the folder list sorted order.

2.1.3 (2111)
------------
_released 2007-07-05_
(2.1.3 Release Build)

- When opening a link in Vienna, the shift key overrides "Open new links in the background" preference.
- Improved drag and drop of feeds to Safari.
- Fixed character encoding issues with exporting subscriptions.
- If Vienna doesn't handle the URL scheme (e.g., itms), open the URL with the default application for its scheme.
- Update SQLite to 3.4.0.

2.1.2 (2110)
------------
_released 2007-04-07_
(2.1.2 Release Build)

- Fixed bug: empty trash warning did not reappear after unhiding Vienna.
- Changed button tooltip to match behavior.
- New and nicer toolbar icons made by Davide Casali (Folletto).
- Fixed bug: move articles to Trash preference was counting back to beginning of day rather than by 24 hours.
- Fixed bug: change in JavaScript preference didn't take effect until relaunching.

2.1.1 (2109)
------------
_released 2007-01-27_
(2.1.1 Release Build)

- Added Danish localisation. (Thanks to David Munch).
- Added Czech localisation. (Thanks to Jakub Formanek).
- If folder manual sort order is corrupt, automatically reset.
- Fix date parsing for fractional seconds.
- The -profile switch is now propagated to a new instance of Vienna if Vienna is restarted.
- Added more built-in styles.
- Add Advanced preferences page and help file page to match.
- Fixed bug where folder passwords were not being properly saved and loaded.
- Save open tabs with unloaded URLs.
- Fix bug: when selecting articles list via right-click, menu items were disabled.
- When manually refreshing all subscriptions, reset the automatic refresh timer.
- Article title appears when article is dragged to iChat (and probably other to apps).
- If a feed item lacks a guid, identify the item by full title and link rather than by a hash.
- Added Applescript command: "mark all subscriptions read".
- Single-key shortcut 'n' for Next Unread command.
- Empty trash automatically on quitting. (Thanks to Hwang Hi.)
- Fix bug: subscriptions duplicated when exporting by AppleScript. (Thanks to Darren Kulp.)
- Support blogging with Pukka.
- Email page link from browser tab.
- Don't show dialog when exporting subscriptions by AppleScript.  (Thanks to Darren Kulp.)
- Added iTunes-like behaviour for add-button. Holding down Option will toggle to "New Smart Folder".
- Added BlogThing to list of supported blog editors.
- Help localized to German.
- Enable JavaScript for styles using the file "script.js", if it exists. (Thanks to Les Orchard).
- Fix bug: article pane failed to display articles for subscriptions with feed: URL.
- Don't unnecessarily refresh article pane after folder refresh.
- Fix DefaultDatabase preference.

2.1.0.2108
----------
_released 2006-11-10_

- Convert InfoPlist.strings files to UTF-16.
- Fix bug with marking all subscriptions read from group or smart folder.

2.1.0.2107
----------
_released 2006-11-05_

- Fix article selection after deleting or restoring.
- Fix bug: deleted article wasn't removed from trash when using filter.

2.1.0.2106
----------
- Only allow the active web view to set the status bar text.
- Added Simplified Chinese localisation. (Thanks to Arsen Liang).
- Don't create a new article if the only difference is the article link.
- Fix bug: article list rows were too small for text.
- Fix bug: next unread command didn't respect folder unexpanded state.
- Fix bug: articles with date but no time were sometimes missed because of midnight timestamp.
- Turn off article updating by default.
- Speed up folder loading by only parsing visible summaries.
- Fix folder refreshing for mark read/unread and undo.

2.1.0.2105
----------
_released 2006-09-23_

- Add Blog With feature.
- Fix bug where mouse was tracking wrong browser tab.
- Fix bug: searching in 'any' smart folders wasn't done correctly.
- Updated all localisation except Traditional Chinese.
- Added Brazilian Portuguese localisation (thanks to Helvécio Mafra).
- Change URL with feed:// to http:// during refresh.
- Fix bug with expanding file:// path.
- Compare article titles case insensitively when looking for updates.
- Fix warning message for missing style.
- Add hidden preference to disable checking for updated articles.
- After clicking link in article pane to open in foreground of external browser,
  return focus to article list.
- Fix bug in date parser.
- If there are no connection errors during refresh, then set the subscription's
  last update date even if there is no data.  Could be http 304, for example.
- Added Korean localisation (thanks to Lee Seung Koo).
- Add AppleScript command for emptying trash.
- "Text contains" in smart folders now matches partial words.

2.1.0.2104
----------
_released 2006-08-27_

- Update to Sparkle 1.1.
- Fix bug: preserved article is marked unread after folder reloaded.
- Fix bug: browser buttons were always enabled.
- Turn on manual sorting by default for new databases.
- When checking for new articles, include articles within 24 hours before last update,
  because feeds sometimes provide inaccurate dates.
- Assign new id to non-duplicate article with same id as existing article.
- Set our own last update date. Don't rely on the feed.
- Ensure that the article guid is truly unique between feeds.
  This fixes a bug where the wrong article was selected.
- Change browser address bar image into button.
- Re-enable Tiger-only features and eliminate warnings in log.
- Fix bug: don't rename when clicking on grayed-out folder.
- Show article list tab when clicking on folders list.
- Allow dragging of Trash folder.
- Don't re-sort article list after changing article's marked or read status.
- Truncate status bar text in the middle when it doesn't fit.
- Fix bug: articles with same title but different links were treated as the same.
- Fix bug: Deleted articles could be marked as updated.
- Standardize browser user agent string.
  This prevents a crash with the Flash Player plugin.
- Green icon for articles with updated article text.
- Improve handling of images with relative URLs.
- Patch from Peter Hosey: open article URL by drag and drop from article list to browser.
- Prevent crash with broken folder sort order (probably from earlier beta version).
- Remove hover:after element in Perlucida style to prevent WebKit crash in 10.3.9.
- Fix bug with dragging and dropping folders when group folder was dragged into itself.
- Prevent crash when deleting folder while editing name.
- Switch everyone to manual folder sorting.

2.1.0.2103
----------
_released 2006-07-27_

- Fix next unread behavior in sorted article list.
- Select a new subscription after dragging from an external source.
- Add Applescript support for retrieving html source of article pane.
- Fix bug: only use xml:base for relative urls.
- Always reload current folder after refresh in report layout, preserving currently selected article if necessary.
- Mark article unread when the article text has changed.
- Add "Get Info" to folder contextual menu.
- Return key in folders list opens home page.
- Changed wording of expired articles preference.
- Single-click folder to rename.
- Limit summary text to 150 characters.
- Add Folder submenu to main menu.
- Fix bug: multiple layouts receiving notifications.
- Fix bug: folders tree sort method wasn't recovered properly from database after plist deletion.
- Extend copyright to all contributors.

2.1.0.2102
----------
_released 2006-07-02_

- Fixed bug: folder attributes (e.g., unread count) not always written to database.
- Don't reload current folder after refresh if preference is set to mark articles read automatically.
- Avoid leaking or crashing with URL connections.
- Move storage of preference for folder sort method from preferences file to database,
  so that it (and manual sort order) can survive deletion of preferences file.
- Enable reloading of web page that never loaded because of error.
- Fixed bug: When deleting multiple folders, the currently selected folder remained selected.
- Enable use of backward delete key.
- Removed multiple delete commands from main menu.
- Added rudimentary Applescript support for retrieving html source of current browser tab.
- Adjust refresh check timer after waking from sleep to account for time asleep. Wait at least 15 seconds
  before refreshing after wake to avoid connection errors.
- When updating existing articles during refresh, don't change article flags.
- Fix bug: existing articles updated even when body hasn't changed.
- Handle relative URLs in article pane.
- Automatic check for folder image only occurs once.
- Fix bugs: next sibling not set for new folder or for folder moved to first child of root node.
- Select new group folder after creating.

2.1.0.2101
----------
_released 2006-06-05_

- Restored Mac OS 10.3.9 support.

2.1.0.2100
----------
(Contributions from Jeffrey Johnson, Michael Ströck and David Kocher).
- Added preference for automatically or manually sorting folders view.
- Added "Increase text size" and "Decrease Text Size" for browser view.
- Changed key combination for "Cancel Refreshing" to control-command-s to make command-"-" available for text size.
- Added "Send Link" functionality for article view.
- Add address bar and refresh, back and forward buttons at the top of the browser web pages.
- Add -profile command line option to support custom profiles (needed for Portable Vienna).
- Added "Refresh Folder Images" command.
- Sort article list by multiple columns, saving the order in which columns were sorted.
- Added "Summary" field which shows the first part of the description.
- In condensed reading mode with the pane on the right, the headline fields can now be configured.
- Added "Filter By" to allow articles to be filtered in the article list by all, unread or date.
- Persist open tabs when Vienna exits and restore them when it restarts.
- Handles HTTP 410 to mark a feed as unsubscribed.
- Add button to Mark All Read the selected feeds.
- Unread articles marked as bold.
- Don't select first article when switching folders.
- Renaming folders now done by editing the name in the folder pane.
- Changed modifier key for overriding default browser preference from shift to option.
- Add Get Info command option and moved Validate command to the info panel.
- New Layout menu: report, condensed and unified layouts.
- Provide two new options for new articles notifications: bounce dock icon or no notification at all.
- Searching with 'contains' or 'not contains' now matches complete words only.
- Add Keyboard Shortcuts item to Help menu.
- Change user agent string from Mozilla/Safari to Vienna.
- Use Sparkle framework (http://andymatuschak.org/pages/sparkle) for version updates.

 2.0.4.2034
-----------
_released 2006-05-17_

- Changed modifier key for overriding default browser preference from shift to option.

2.0.4.2033
----------
- Parse entity characters in RSS article links.
- Various bug and performance fixes.

2.0.3.2032
----------
_released 2006-04-08_

- Minor article cache tweak and bug fixes.

2.0.3.2031
----------
- Completed Japanese localisation.
- Support Local File subscriptions in New Subscription sheet.
- Bug fixes.

2.0.2.2030
----------
_released 2006-03-07_

- Completed Spanish localisation.

2.0.2.2029
----------
- Fix database performance issue introduced in 2026.

2.0.1.2028
----------
_released 2006-03-01_
(2.0.1 Release Build)

- Updated localisation.

2.0.1.2027
----------
- For feeds that have no title and one cannot be synthesised, we now set the title to (No Title).
- Made click on the Growl notification work again. It broke when we moved to 0.7.4.
- Correctly set focus on the web page in a new tab. (Code contributed by Jeffrey Johnson).
- Fix a build 2025 crashing bug.
- Several localisation updates.

2.0.1.2026
----------
- Universal binary build.
- Updated to Growl 0.7.4.
- No longer prompt if Vienna is exited while a connection is in progress.
- Better truncation of feed names in the folder list. (Code contributed by David Kocher).
- Handle HTML redirects in the feed for sources such as MSN Spaces.
- Save and restore the currently selected article when you exit and restart Vienna.
- Support use of the Shift key to open a link in the alternate browser. (Code contributed by Jeffrey Johnson).
- Added Japanese localisation. (Thanks to Daisuke).
- Added Spanish localisation. (Thanks to Carlos Morales).
- Shift+Spacebar scrolls up the article view or goes to the previously viewed message.
- Added four more built-in styles: Broadsheet Clipping, Perlucida, Prague and Prague-light.

2.0.0.2025
----------
_released 2006-02-07_
(2.0 Release Build)

- Added Dutch localisation (Thanks to Martijn van Exel).
- Fix corrupted display of iframe on some articles due to encoding mismatch.
- Fix Mark All Read behaviour in smart folders which broke in 2024.
- Fix crash on closing tabs.

2.0.0.2024
----------
- Additional memory usage improvements.

2.0.0.2023
----------
_released 2006-01-23_

- Incorporated a fix from Mark Evenson for the cursor.org RSS feed.
- Refresh keystrokes changed to Cmd+R/Shift+Cmd+R.
- Mark Read keystroke changed to Cmd+Shift+U ('u' single key added to complement).
- New Smart Folder keystroke changed to Cmd+Shift+F.
- Reload Page keystroke changed to Alt+R.
- Added Cmd+Alt+K to Mark All Subscriptions as Read.
- Made a few internal optimisations to try and reduce memory usage and database update frequency.
- Added French help file and some French localisation fixes.
- Other minor bug fixes.

2.0.0.2022
----------
_released 2006-01-16_

- More feed parsing issues fixed.
- Improved General and Appearance icons contributed by Brandon Booth.

2.0.0.2021
----------
_released 2006-01-12_

- Fixed a few left-over localisation issues.
- Parse out a subset of HTML tags from titles.
- Add a fix for unescaped & characters in links which some feeds are prone to.
- Replaced Preference icons as the originals turned out to copyrighted to Nitram+Nunca.

2.0.0.2020
----------
_released 2006-01-07_

- New 'star' shaped unread count on the application icon.
- Disable Delete Article unless the article list has focus.
- Minor fit-and-finish polish to the UI and parsing code.

2.0.0.2019
----------
_released 2006-01-01_

- New RSS feed icon.
- Fixed a few more feed parsing issues.

2.0.0.2018
----------
_released 2005-12-27_

- Improved handling of feeds with invalid XML encoding so most of these are now accepted.
- Fix Growl integration to work in localised builds.
- Fix handling of folder icons from sites like FeedBurner.
- Finalised help file for 2.0 release.

2.0.0.2017
----------
_released 2005-12-22_

- Fix localisation article scroll bar truncation.
- Clear download list should not remove items being downloaded.
- Fix handling of Javascript web pages.
- Add three more built-in styles: Tyger, Vienna Pride, EasySimple and Felix.
- Added Demo RSS feeds for new databases.
- Fix parsing of atom xml:base links.
- Added "current selection" Applescript method to return the current text selection.
- Don't undo when doing "Mark All Subscriptions as Read".

2.0.0.2016
----------
_released 2005-12-16_

- Added Traditional Chinese localisation. (Thanks to Weizhong Yang).
- Accept HTTP 200 responses with no data as meaning 0 new articles rather than an error.
- Show count of unread on title bar. (Patch submitted by Jussi Hagman).
- Minor bug fixes.

2.0.0.2015
----------
_released 2005-12-03_

- Improvements to universal date parsing to fix some mis-parsed article dates.
- Fixed OPML format in exported subscriptions to conform to the standard.
- A warning icon now appears next to the folder name in the folders list if an error
  occurred when the feed was last refreshed.

2.0.0.2014
----------
_released 2005-11-25_

- Fix "Folder NOT xxx" implementation which wasn't working right for group folders.
- Cmd+W closes the Download, Preference or Activity windows even when they are active.
- $FeedDescription$ added as a tag for styles. This expands to the feed description if available.
- Fixed bug where AppleScript 'current article' on an article in a group returns a null reference.
- Search field now also searches in titles.
- Confirmation prompt added before emptying the trash folder.
- Download window now allows double-click to open a downloaded file.
- Added popup menu to download window.

2.0.0.2013
----------
_released 2005-11-05_

- Resort the folder list when a folder is renamed.
- Cmd-click on a link in the web view opens the link in a new tab.
- Download SITX files as SITX files even if the server returns a MIME type of text.

2.0.0.2012
----------
_released 2005-10-28_

- Fix bug which prevented a system from going to sleep if automatic refreshes are enabled.
- Stepping through article lists does not refresh the article pane until the steps complete.
- Completed all localisation fixes.
- Auto-expire now runs post-refresh in addition to at start up.
- Vienna now checks that it can create the database in the users home folder and prompts
  for an alternative location if not.
- Don't scroll the current article after a refresh if it hasn't been changed or expired.

2.0.0.2011
----------
_released 2005-10-20_

- Added option to export subscriptions with groups or as a flat file.
- Refresh when the system awakes from sleep if the refresh frequency is not set to manual.
- Added German Localisation. (Thanks to Jan Kampling).
- Improved handling of invalid styles.
- Vienna can now download files. A new Downloads window has been added which tracks the file
  downloads. The downloads folder can now be configured via Preferences.
- Added "Mark All Subscriptions as Read" command. (Thanks to Yann Bizeul).
- Incorporated patches from Yann Bizeul and Adam Hammer.
- Close button on tabs now depress and highlight properly.
- New Preferences UI.
- Font selection in Preferences changed to use the standard OS font picker.
- Add an option to disable feed folder images in the folders list.
- Moved unread count on application icon to the top right corner to be consistent with most
  other Mac OSX applications.
- Support dragging URL strings from other applications into the folders pane.
- Support dropping script files (.scpt) on the application icon to install them to the Vienna
  script folder and add them to the Scripts menu.

2.0.0.2010
----------
_released 2005-10-05_

- Added auto-expire support. Articles older than a given number of days can be automatically moved
  to the trash folder.
- Handle RDF:Sequence parsing for feeds such as http://www.kongisking.net. This ensures that
  feeds are properly organised by date in the absence of any date in the feed.
- Smart folder dates fields are now fixed strings representing a time range rather than an actual date.
- Added Italian Localisation. (Thanks to Marcello Teodori).
- Pre-build 2005 format databases no longer upgraded.
- Removed old format display style conversion code. Styles on the web site have been updated.
- Fixed bug where smart folder criteria was unintentionally extended when doing a filtered search.
- Changed a couple of default preferences. We no longer check for new articles on startup and the
  default layout is now to have the article pane at the bottom.
- Fixed growl notification handling not bringing the main window to the foreground.
- Added "Skip Folder" command to mark all articles in the current folder read and skip to the next
  folder with unread articles. The shortcut key for this is 'S'.

2.0.0.2009
----------
_released 2005-09-26_

- Fixed potential database corruption bug introduced in build 2007 when refreshing a feed that
  uses entity characters specified with hexadecimal notation.
- Cmd+W closes Preferences window if it is open, rather than the main window.
- The "About Vienna" window can now be closed with Esc or Cmd+W.
- Reduced height of tabs slightly.
- Holding down Cmd+Alt keys while clicking tab close button closes all tabs.
- Fixed close tab behaviour properly this time.

 2.0.0.2008
-----------
_released 2005-09-24_
(2.0 BETA 2 build)

- Added final Swedish localisation changes for beta 2.
- Fixed French localisation import error.
- Fix bug with importing OPML files.
- Added 'group folder', 'smart folder' and 'rss folder' attributes to folder class in scripting.
- Added Restore command to restore an article in the Trash Folder back to where it came from.
- Fixed UI update bug when a folder is deleted during a refresh.
- Exported files now have ".opml" extension added to them.
- Smart search folder operators are now limited to "is" and "is not" as "under" is now implied.
- Encode extended characters in HTML article text dragged from the article list view.

2.0.0.2007
----------
_released 2005-09-18_

- You can now undo/redo Mark All Read, even across multiple folders.
- Article view split bar position is now properly persisted across sessions.
- Disabled proportional folder and article list split bar resizing when the main window is resized.
- Selecting multiple articles now shows multiple articles in the article pane.
- Fixed problem when parsing feeds from http://macintouch.com/rss.xml. Some servers report an
  error unless the User-agent field is specified in the HTTP header.
- Added built-in browser support. Web pages can now be opened in Vienna in separate tabs as an
  option. Next and Previous Tab commands added to the Window menu. Close Tab added to the File
  menu. Right-click popup menu allows links or pages to be opened externally.
- Added option in Preferences to open web pages in Vienna.
- Close Window command changed to Shift+Command+W when tabs are open for consistency with
  Camino and Safari.
- Fixed a bug that screwed up sorting by the read column.
- Improved printing of articles.
- Can undo moving folders in the folders list pane.
- Several improvements to AppleScript interface: new attributes and fixed some bugs.
- Added Cmd+U for next unread since Spacebar doesn't work from the web view.

2.0.0.2006
----------
_released 2005-09-03_

- Can now sort and double-click activity log items.
- Added option to set the minimum font size in the article display pane.
- Search field now searches article titles as well as the text.
- New application icon. (Thanks to Jasper Hauser - http://www.jasperhauser.nl/icon/).
- Added French localisation. (Thanks to Cyril Gautrias).
- Dropped Compact Database command from the File menu. This is now accessible through the
  scripting interface. Most people don't actually need to compact the database now.
- Added "Validate Feed" command to the File menu.

2.0.0.2005
----------
_released 2005-08-19_

- Updates to Swedish localisation.
- Fixed entity decoding bug that caused corrupted characters in the Der Spiegel feed.
- Fixed character set translation bug that caused some UTF8 characters to appear corrupted.
- Improvements to handling of article GUID/ID to eliminate duplicate articles and better
  track articles that have been modified. This change requires a database upgrade.
- Left/Right arrow keys now move between the folder list and the articles list.
- Added Trash folder. Delete Article now moves selected articles to the Trash folder. New
  Empty Trash command on the Vienna menu can be used to empty the trash folder. (Note: it
  is intentional that you can rename the Trash folder).
- Added Undo/Redo support for the following actions: marking articles read, marking articles
  flagged, renaming folders and deleting articles.
- Spacebar now moves to next unread article.
- Enter key now opens the current article in the default system browser. ('P' to open the
  current article in the article pane has been removed.)
- < and > keys now move to previous and next article.
- Drag from the article list now provides HTML and string versions on the pasteboard.
- Copy now works on articles in the article list and folders in the folder list.
- Added an option to open links clicked in Vienna in the background in the default browser.
- New temporary application icon that is more 'clickable' than the old one. A better icon
  is planned for later.
- Added "More Styles..." to end of Styles menu that opens the Vienna downloads web site in the
  default browser.
- Improved the UI refresh after drag and drop re-ordering of folders in the folder list.

2.0.0.2004
----------
_released 2005-07-28_
(Refresh)

- Added support for automatically installing custom styles.
- Refresh button now toggles between starting and stopping a refresh.
- Remove the unread count from the application icon in the dock when closing Vienna.
- Fixed bug where authenticated feeds did not prompt for first time credentials.

2.0.0.2004
----------
- Add Scripts menu that displays all scripts under ~/Library/Scripts/Applications/Vienna. By
  default this is enabled under Mac OSX 10.3 and disabled under 10.4 since there is a system
  wide Scripts menu on the status bar that replicates this functionality.
- Rewrote the code that registers the default RSS reader. It wasn't picking up all possible
  candidates. Now it shows all candidate applications and also adds a Select... option so the
  user can manually search for the application. This also fixes the bug where Vienna took over
  the feed handler from others without permission.
- Smart folders now support 'any' in addition to the implied 'all' condition. So you can now
  create folders which match any one or more combination of criteria.
- Clicking the dock icon now reopens the main window if it was previously closed.
- Added Swedish localisation (contributed by Christoffer Larsson).
- Several internal fixes for issues thrown up by Swedish localisation.
- View->Next Unread now goes to folders that have subscriptions with unread articles as well
  as to the subscriptions themselves. This causes Vienna to respect the closed state of group
  folders.
- Improved the logic by which folder images are retrieved to make this more reliable.
- New About Vienna window.
- The count of unread articles now show up as button in the folder list to the right of each
  subscription name.
- The Search field now searches immediately rather than wait for you to press Enter.
- Fixed bug that causes images not to render in feeds where embedded links to images are
  relative to the URL of the feed rather than absolute URLs.
- Add 'Validate Feed' command.

2.0.0.2003
----------
_released 2005-07-16_

- Add an option to mark the current article read after 1 second. This is now the new default.
- Fix import/export to convert characters such as <, > and & to and from their entity equivalents
  in URL fields as per XML specification.
- Add View->Article Page to display the original web page from which the article came. The short
  cut for this is 'P'. The command toggles between the web page and the original article.
- Support content:encoding in RSS 2.0 feeds and use that to override description where available.
  (This fixes the parsing of sites such as http://feeds.feedburner.com/MajorNelson).
- In Atom feeds, where no explicit author is specified for an article, use the feed author if available.
- Mark All Read now works in smart folders.
- Add File->Close Window command to close the main Vienna window and Window->Main Window to reopen
  it again. While the main window is closed, all UI commands are disabled.
- Add "Refresh All Subscriptions" to the application dock menu. Other things will follow on the
  dock menu but this was the most common one that people requested.
- Trim title fields to the first non-blank line. Some feeds had titles with multiple lines and
  these cause display problems in the UI.
- When subscribing to a feed, we now check to see if there's an active connection available and if
  so, we refresh the new feed immediately. If there's no active connection then the refresh is
  deferred.
- New layout style when the article pane is to the right of the article list. In this layout, the
  articles are automatically displayed in summary style with four fixed columns. (Note that you
  cannot add or remove columns in this layout). When the article pane is at the bottom, the usual
  table layout appears. For simplicity I haven't exposed any way to change layout independently
  of the position of the article pane. It'll be interesting to see if anybody really wants the
  summary view when the article pane is below the article list.

2.0.0.2002
----------
_released 2005-07-07_
(2.0 BETA 1 build)

- Original beta 1 release.
