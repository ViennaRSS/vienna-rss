#!/bin/sh

VIENNA_UPLOADS_DIR="$BUILT_PRODUCTS_DIR/Uploads"
VIENNA_NOTES="$SRCROOT/notes.html"
VIENNA_CHANGELOG="changelog$VIENNA_CHANGELOG_SUFFIX.xml"

if [ "$CONFIGURATION" = "Deployment" ] ; then
echo "Running script to create web site files"
if [ ! -e "$VIENNA_UPLOADS_DIR" ] ; then
mkdir "$VIENNA_UPLOADS_DIR"
fi
cd "$VIENNA_UPLOADS_DIR"

if [ -e "$VIENNA_NOTES" ] ; then
cp -f "$VIENNA_NOTES" "noteson$VIENNA_VERSION_NUMBER.$BUILD_NUMBER.html"
fi

rm -f "$VIENNA_CHANGELOG"

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$VIENNA_CHANGELOG"
echo "<rss version=\"2.0\" xmlns:sparkle=\"http://www.andymatuschak.org/xml-namespaces/sparkle\">" >> "$VIENNA_CHANGELOG"
echo "<channel>" >> "$VIENNA_CHANGELOG"
echo "<title>Vienna Changelog</title>" >> "$VIENNA_CHANGELOG"
echo "<link>http://vienna-rss.sourceforge.net</link>" >> "$VIENNA_CHANGELOG"
echo "<description>Vienna Changelog</description>" >> "$VIENNA_CHANGELOG"
echo "<language>en-us</language>" >> "$VIENNA_CHANGELOG"
echo "<copyright>Copyright 2010, Steve Palmer</copyright>" >> "$VIENNA_CHANGELOG"
echo "<item>" >> "$VIENNA_CHANGELOG"
echo "<title>Vienna $VIENNA_VERSION_NUMBER.$BUILD_NUMBER</title>" >> "$VIENNA_CHANGELOG"
echo "<pubDate>$(date '+%a, %d %b %G %T %z')</pubDate>" >> "$VIENNA_CHANGELOG"
echo "<link>http://master.dl.sourceforge.net/project/vienna-rss/Released%20Versions/$VIENNA_VERSION_NUMBER/Vienna$VIENNA_VERSION_NUMBER.$BUILD_NUMBER.zip</link>" >> "$VIENNA_CHANGELOG"
echo "<sparkle:minimumSystemVersion>10.4.0</sparkle:minimumSystemVersion>" >> "$VIENNA_CHANGELOG"
echo "<enclosure sparkle:version=\"$BUILD_NUMBER\" url=\"http://master.dl.sourceforge.net/project/vienna-rss/Released Versions/$VIENNA_VERSION_NUMBER/Vienna$VIENNA_VERSION_NUMBER.$BUILD_NUMBER.zip\" type=\"application/octet-stream\"/>" >> "$VIENNA_CHANGELOG"
echo "<sparkle:releaseNotesLink>http://vienna-rss.sourceforge.net/noteson$VIENNA_VERSION_NUMBER.$BUILD_NUMBER.html</sparkle:releaseNotesLink>" >> "$VIENNA_CHANGELOG"
echo "</item>" >> "$VIENNA_CHANGELOG"
echo "</channel>" >> "$VIENNA_CHANGELOG"
echo "</rss>" >> "$VIENNA_CHANGELOG"
fi

exit 0
