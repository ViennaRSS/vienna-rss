#!/bin/bash

set -o errexit

echo "Prepare publication to Github"

DOWNLOAD_BASE_URL="https://github.com/downloads/ViennaRSS/vienna-rss"
# VERSION is similar to 2.6.0.2601 , BUILD_NUMBER is similar to 2601
VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Info" CFBundleShortVersionString)
BUILD_NUMBER=$(defaults read "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Info" CFBundleVersion)

VIENNA_BUILD_NAME="$PRODUCT_NAME$VERSION"
VIENNA_UPLOADS_DIR="$BUILT_PRODUCTS_DIR/Uploads"
ARCHIVE_FILENAME="$VIENNA_BUILD_NAME.zip"
DOWNLOAD_URL="$DOWNLOAD_BASE_URL/$ARCHIVE_FILENAME"

WD=$PWD

codesign -f -s 'Developer ID Application' "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app"

if [ ! -e "$VIENNA_UPLOADS_DIR" ] ; then
	mkdir "$VIENNA_UPLOADS_DIR"
fi

cd "$BUILT_PRODUCTS_DIR"
rm -f "$VIENNA_UPLOADS_DIR/$PRODUCT_NAME"*.zip

# Application
ditto -ck --keepParent "$PRODUCT_NAME.app" "$VIENNA_UPLOADS_DIR/$ARCHIVE_FILENAME"

SIZE=$(stat -f %z "$VIENNA_UPLOADS_DIR/$ARCHIVE_FILENAME")
PUBDATE=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")

# dSYM
VIENNA_APP_DSYM="$PRODUCT_NAME.app.dSYM"
if [ -e "$VIENNA_APP_DSYM" ] ; then
	ditto -ck --keepParent --sequesterRsrc "$VIENNA_APP_DSYM" "$VIENNA_UPLOADS_DIR/$VIENNA_BUILD_NAME.dSYM.zip"
fi

# Notes related to this build
VIENNA_NOTES="$SRCROOT/notes.html"
RELEASENOTES_URL="$DOWNLOAD_BASE_URL/noteson$VERSION.html"

if [ -e "$VIENNA_NOTES" ] ; then
	cp -f "$VIENNA_NOTES" "$VIENNA_UPLOADS_DIR/noteson$VERSION.html"
fi

# Changelog for Sparkle
cat > "$VIENNA_UPLOADS_DIR/changelog$VIENNA_CHANGELOG_SUFFIX.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel>
<title>Vienna Changelog</title>
<link>http://vienna-rss.sourceforge.net</link>
<description>Vienna Changelog</description>
<language>en-us</language>
<copyright>Copyright 2010-2012, Steve Palmer and contributors</copyright>
<item>
<title>BETA Version ($VERSION)</title>
<sparkle:releaseNotesLink>$RELEASENOTES_URL</sparkle:releaseNotesLink>
<pubDate>$PUBDATE</pubDate>
<enclosure
url="$DOWNLOAD_URL"
sparkle:version="$BUILD_NUMBER"
type="application/octet-stream"
length="$SIZE"
/>
<sparkle:minimumSystemVersion>10.5.0</sparkle:minimumSystemVersion>
</item>
</channel>
</rss>
EOF

