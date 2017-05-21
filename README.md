![Vienna](https://vienna-rss.sourceforge.io/img/vienna_logo.png)

[![Build Status](https://travis-ci.org/ViennaRSS/vienna-rss.svg?branch=master)](https://travis-ci.org/ViennaRSS/vienna-rss)
[![Crowdin](https://d322cqt584bo4o.cloudfront.net/vienna-rss/localized.svg)](https://crowdin.com/project/vienna-rss)
[![Gitter chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/ViennaRSS/Lobby)

[Vienna](http://www.vienna-rss.com) is an RSS/Atom reader for macOS.

Vienna can connect directly to the websites you want to track.
Additionally or alternatively, you can also sync with a server supporting the [Open Reader API](http://rss-sync.github.io/Open-Reader-API/rssconsensus/) (an adaptation of the now deceased Google Reader API). Vienna has been successfully tested with BazQux.com, FeedHQ.org, InoReader.com and TheOldReader.com.


Compatibility
-------------

Vienna 3.1.x requires a minimum of OS X 10.8 (Mountain Lion).
The next version of Vienna (3.2.x) will require a minimum of OS X 10.9 (Mavericks).


Installing
----------

Admins upload release and test versions at [bintray](https://bintray.com/viennarss/vienna-rss/vienna-rss/) and [Sourceforge](https://sourceforge.net/projects/vienna-rss/files/).  
Alternatively, you can download releases from the [GitHub Releases page](https://github.com/ViennaRSS/vienna-rss/releases)

**Homebrew**

Vienna is also available as a Cask for [Homebrew Cask](https://github.com/phinze/homebrew-cask).
```bash
brew cask install vienna
```

Getting support
---------------

If the in-application help files and the [FAQs](http://www.vienna-rss.com/?page_id=96) don’t answer your questions, head over to our [Support forum](https://forums.cocoaforge.com/viewforum.php?f=18) which is hosted by Cocoaforge.

Reporting an issue
------------------

If after reading the forum and asking your questions there, you are convinced that there is a problem in Vienna's code or an important feature is missing, you may open an [issue](https://github.com/ViennaRSS/vienna-rss/issues?direction=desc&sort=created&state=open) on Github.

Be concise, but as precise as possible to allow other people reproducing the issue. To keep things short, you can provide a link to a relevant thread or message on the Cocoaforge forum.

Contributing
------------

Want to contribute? Great! There are many ways you can, even if you aren't a developer.

### Localizing ###

We need help keeping Vienna translations up to date into different languages. Apart from English, here are the languages for which a localization effort has started:

* Basque (eu)
* Simplified Chinese (zh-Hans)
* Traditional Chinese (zh-Hant)
* Czech (cs)
* Danish (da)
* Dutch (nl)
* French (fr)
* Galician (gl)
* German (de)
* Italian (it)
* Japanese (ja)
* Korean (ko)
* Portuguese (pt)
* Brazilian Portuguese (pt-BR)
* Russian (ru)
* Spanish (es)
* Swedish (sv)
* Turkish (tr)
* Ukrainian (uk)

You can contribute localizations at [Crowdin](https://crowdin.com/project/vienna-rss). Registration is required, but the account is free. Although Crowdin is preferred, you can also submit localizations via pull request, by editing the relevant files (e.g. \*.strings) directly.

### Writing custom styles

Vienna supports a variety of different display styles for articles. These styles are provided on the Styles sub-menu off the View menu. A style is a combination of an HTML template that is used to control the placement of various parts of the article and a CSS stylesheet that controls the appearance of the article.

You can write styles by referring to [this document](http://www.vienna-rss.com/?page_id=65). Have a look at existing styles in the __Styles__ folder.

### Writing plugins

Vienna supports plugins which are installed in menus and/or on the toolbar and can run defined actions. These plugins are XML-based and can be created by editing a simple .plist-file without any knowledge of Cocoa programming, in as little as 15 minutes.

You can write plugins by referring to [this document](http://www.vienna-rss.com/?page_id=120). Have a look at existing plugins in the __Plugins__ folder.

### Writing code

The current version of Vienna requires Xcode 8.x and macOS 10.12 SDK. Most of Vienna is made with Objective-C but some newer code is being created in Swift 3.x and we welcome both Objective-C and Swift contributions.

Vienna uses [cocoapods](https://cocoapods.org) for managing dependencies. When building, make sure to always open the Xcode workspace `Viennna.xcworkspace` instead of a project file.

You should have a basic knowledge of Git and read this [suggested workflow](https://github.com/ViennaRSS/vienna-rss/wiki/Good-manners-with-Git).

As a starting point, search for any [issues with the *help-wanted* label](https://github.com/ViennaRSS/vienna-rss/issues?q=is%3Aopen+is%3Aissue+label%3Ahelp-wanted).

Please let us know what you are working on by posting an issue on Vienna's github and assigning it to yourself.

For more information please check [CONTRIBUTING.md](CONTRIBUTING.md).


Licensing
---------

[Apache License, Version 2.0](LICENCE.md).
