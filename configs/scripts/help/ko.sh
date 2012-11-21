#!/bin/sh

VIENNA_LOCALIZATION="ko"
VIENNA_MIN_TERM_LENGTH=1
VIENNA_LOCALIZED_HELP_FOLDER="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/$VIENNA_LOCALIZATION.lproj/Vienna Help"

if [ -x /usr/bin/hiutil ] ; then
	/usr/bin/hiutil -C -avv -m $VIENNA_MIN_TERM_LENGTH -f "$VIENNA_LOCALIZED_HELP_FOLDER/Vienna Help.helpindex" "$VIENNA_LOCALIZED_HELP_FOLDER"
else
	"$SYSTEM_DEVELOPER_DIR/Applications/Utilities/Help Indexer.app/Contents/MacOS/Help Indexer" "$VIENNA_LOCALIZED_HELP_FOLDER" -UseRemoteRoot NO -IndexAnchors YES -MinTermLength $VIENNA_MIN_TERM_LENGTH -ShowProgress YES -LogStyle 2
fi
