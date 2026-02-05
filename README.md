![Vienna](https://www.vienna-rss.com/images/vienna_logo.png)

[![Build status](https://github.com/ViennaRSS/vienna-rss/actions/workflows/xcodebuild.yml/badge.svg)](https://github.com/ViennaRSS/vienna-rss/actions/workflows/xcodebuild.yml)
[![Localization status](https://d322cqt584bo4o.cloudfront.net/vienna-rss/localized.svg)](https://crowdin.com/project/vienna-rss "Crowdin")

[Vienna](https://www.vienna-rss.com) is an RSS/Atom/JSON Feed reader for macOS.

Vienna can connect directly to the websites you want to track.
Additionally or alternatively, you can also sync with a server supporting the [Open Reader API](http://rss-sync.github.io/Open-Reader-API/rssconsensus/) (an adaptation of the now deceased Google Reader API). Vienna has been successfully tested with BazQux.com, FreshRSS.org, FeedHQ.org, InoReader.com and TheOldReader.com.


Compatibility
-------------

Version 3.9.x requires a minimum of macOS 10.13 (High Sierra).  
Vienna 3.8.x requires a minimum of macOS 10.12 (Sierra).  
Vienna 3.6.x and 3.7.x require a minimum of OS X 10.11 (El Capitan).  
Vienna 3.2.x to 3.5.x require a minimum of OS X 10.9 (Mavericks).  
Vienna 3.1.x requires a minimum of OS X 10.8 (Mountain Lion).  
Vienna 3.0.x requires a minimum of OS X 10.6 (Snow Leopard).


Installing
----------

Admins upload release and test versions at the [GitHub Releases page](https://github.com/ViennaRSS/vienna-rss/releases).  
Alternatively, you can download releases from [Sourceforge](https://sourceforge.net/projects/vienna-rss/files/).

**Homebrew**

Vienna is also available as a Cask for [Homebrew Cask](https://github.com/Homebrew/homebrew-cask).
```bash
brew install --cask vienna
```

Getting support
---------------

If the in-application help files and the [FAQ](https://www.vienna-rss.com/faq) don’t answer your questions, head over to our [Discussions page](https://github.com/ViennaRSS/vienna-rss/discussions) on GitHub.

Reporting an issue
------------------

If after reading the Discussions page or asking your questions there, you are convinced that there is a problem in Vienna's code or an important feature is missing, you may open an [issue](https://github.com/ViennaRSS/vienna-rss/issues?direction=desc&sort=created&state=open) on Github.

Be concise, but as precise as possible to allow other people reproducing the issue. To keep things short, you can provide a link to a relevant discussion.

Contributing
------------

Want to contribute? Great! There are many ways you can, even if you aren't a developer.

This project has strict rules regarding usage of so-called "AI". Please see the [LLM usage policy](LLM-USAGE-POLICY.md).

### Writing code

Please check [CONTRIBUTING.md](CONTRIBUTING.md).

### Localizing ###

We need help keeping Vienna translations up to date into different languages. You can contribute localizations at [Crowdin](https://crowdin.com/project/vienna-rss). Registration is required, but the account is free. Contact us if you want to contribute for a language that is not yet listed. Do not localize the project's files directly.

### Writing custom styles

Vienna supports a variety of different display styles for articles. These styles are provided on the Styles sub-menu off the View menu. A style is a combination of an HTML template that is used to control the placement of various parts of the article and a CSS stylesheet that controls the appearance of the article.

You can write styles by referring to [this document](https://www.vienna-rss.com/extras/creating-custom-styles/). Have a look at existing styles in the __Styles__ folder.

### Writing plugins

Vienna supports plugins which are installed in menus and/or on the toolbar and can run defined actions. These plugins are XML-based and can be created by editing a simple .plist-file without any knowledge of Cocoa programming, in as little as 15 minutes.

You can write plugins by referring to [this document](https://www.vienna-rss.com/development/creating-plugins-for-vienna-2-5/). Have a look at existing plugins in the __Plugins__ folder.

Licensing
---------

[Apache License, Version 2.0](LICENCE.md).
