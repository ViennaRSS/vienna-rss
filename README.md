![Vienna](http://vienna-rss.sourceforge.net/img/vienna_logo.png)

[![Build Status](https://travis-ci.org/ViennaRSS/vienna-rss.svg?branch=master)](https://travis-ci.org/ViennaRSS/vienna-rss) [![Stories in Ready](https://badge.waffle.io/viennarss/vienna-rss.png?label=ready&title=Ready)](https://waffle.io/viennarss/vienna-rss)

[Vienna](http://www.vienna-rss.org) is an RSS/Atom reader for Mac OS X.

Vienna can connect directly to the websites you want to track.
Additionally or alternatively, you can also sync with a server supporting the [Open Reader API](http://rss-sync.github.io/Open-Reader-API/rssconsensus/) (an adaptation of the now deceased Google Reader API). Vienna has been successfully tested with BazQux.com and FeedHQ.org.

Installing
----------

Admins upload release and test versions at [Sourceforge](https://sourceforge.net/projects/vienna-rss/files/).  
Alternatively, you can download releases from the [GitHub Releases page](https://github.com/ViennaRSS/vienna-rss/releases)

**Homebrew**

Vienna is also available as a Cask for [Homebrew Cask](https://github.com/phinze/homebrew-cask).

    brew cask install vienna



Getting support
---------------

If the in-application help files and the [FAQs](http://www.vienna-rss.org/?page_id=96) don’t answer your questions, head over to our [Support forum](http://forums.cocoaforge.com/viewforum.php?f=18) which is hosted by Cocoaforge.

Reporting an issue
------------------

If after reading the forum and asking your questions there, you are convinced that there is a problem in Vienna's code or an important feature is missing, you may open an [issue](https://github.com/ViennaRSS/vienna-rss/issues?direction=desc&sort=created&state=open) on Github.

Be concise, but as precise as possible to allow other people reproducing the issue. To keep things short, you can provide a link to a relevant thread or message on the Cocoaforge forum.

Contributing
------------

Want to contribute? Great! There are many ways you can, even if you aren't a developer.

### Localizing and translating ###

We need help keeping Vienna translations up to date into different languages. Apart from English, here are the languages for which a localization effort has started :

* German
* French
* Swedish
* Italian
* Dutch
* Traditional Chinese
* Spanish
* Japanese
* Korean
* Brazilian Portuguese
* Simplified Chinese
* Danish
* Czech
* Euskara (Basque)
* Russian
* Ukrainian

Have a look at current localizations in their respective _.lproj_ folders. While translating, the [LangSwitch](http://www.seoxys.com/langswitch-2/) freeware might be handy for checking contexts.

### Writing custom styles

Vienna supports a variety of different display styles for articles. These styles are provided on the Styles sub-menu off the View menu. A style is a combination of an HTML template that is used to control the placement of various parts of the article and a CSS stylesheet that controls the appearance of the article.

You can write styles by referring to [this document](http://www.vienna-rss.org/?page_id=65). Have a look at existing styles in the __Styles__ folder.

### Writing plugins

Vienna supports plugins which are installed in menus and/or on the toolbar and can run defined actions. These plugins are XML-based and can be created by editing a simple .plist-file without any knowledge of Cocoa programming, in as little as 15 minutes.

You can write plugins by referring to [this document](http://www.vienna-rss.org/?page_id=120). Have a look at existing plugins in the __Plugins__ folder.

### Writing code

Vienna uses [cocoapods](http://cocoapods.org) for managing dependancies. When building, make sure to always open the Xcode workspace `Viennna.xcworkspace` instead of a project file.

You should have a basic knowledge of Git and read these [advices on workflow](https://github.com/ViennaRSS/vienna-rss/wiki/Good-manners-with-Git).

Please let us know what you are working on by posting an issue on Vienna's github and assigning it to yourself.

Licensing
---------

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html).






