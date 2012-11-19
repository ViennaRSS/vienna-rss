#!/bin/sh

VIENNA_APP="Vienna.app"
VIENNA_ENGLISH="en-us"
VIENNA_APP_ENGLISH="$VIENNA_ENGLISH/$VIENNA_APP"
VIENNA_BUILD_SUFFIX="$VIENNA_VERSION_NUMBER.$BUILD_NUMBER"
VIENNA_BUILD_NAME="Vienna$VIENNA_BUILD_SUFFIX"
VIENNA_UPLOADS_DIR="Uploads"
VIENNA_ZIP_SUFFIX=".zip"
VIENNA_DSYM_SUFFIX=".dSYM"
VIENNA_UPLOAD_PREFIX="$VIENNA_UPLOADS_DIR/$VIENNA_BUILD_NAME"
VIENNA_UPLOAD="$VIENNA_UPLOAD_PREFIX$VIENNA_ZIP_SUFFIX"
VIENNA_UPLOAD_ENGLISH="$VIENNA_UPLOAD_PREFIX.$VIENNA_ENGLISH$VIENNA_ZIP_SUFFIX"
VIENNA_APP_DSYM="$VIENNA_APP$VIENNA_DSYM_SUFFIX"
VIENNA_UPLOAD_DSYM="$VIENNA_UPLOADS_DIR/$VIENNA_BUILD_NAME$VIENNA_DSYM_SUFFIX$VIENNA_ZIP_SUFFIX"

if [ "$CONFIGURATION" = "Deployment" ] ; then
	echo "Running script to create localized and non-localized versions"
	if [ -e "$BUILT_PRODUCTS_DIR" ] ; then
		cd "$BUILT_PRODUCTS_DIR"
		if [ -e "$VIENNA_APP" ] ; then
			if [ ! -e "$VIENNA_UPLOADS_DIR" ] ; then
				 mkdir "$VIENNA_UPLOADS_DIR"
			else
				rm -f "$VIENNA_UPLOAD"
				rm -f "$VIENNA_UPLOAD_ENGLISH"
				rm -f "$VIENNA_UPLOAD_DSYM"
			fi

			ditto -ck --keepParent --sequesterRsrc "$VIENNA_APP" "$VIENNA_UPLOAD"

			rm -fR "$VIENNA_ENGLISH"
			mkdir "$VIENNA_ENGLISH"
			cp -R "$VIENNA_APP" "$VIENNA_APP_ENGLISH"
			find -d "$VIENNA_APP_ENGLISH" -iname "*.lproj" -not -iname "en.lproj" -not -iname "english.lproj" -exec rm -rf {} \;
			ditto -ck --keepParent --sequesterRsrc "$VIENNA_APP_ENGLISH" "$VIENNA_UPLOAD_ENGLISH"

			if [ -e "$VIENNA_APP_DSYM" ] ; then
				ditto -ck --keepParent --sequesterRsrc "$VIENNA_APP_DSYM" "$VIENNA_UPLOAD_DSYM"
			else
				echo "Error: $VIENNA_APP_DSYM does not exist."
				exit 1
			fi
		else
			echo "Error: $BUILT_PRODUCTS_DIR/$VIENNA_APP does not exist."
			exit 1
		fi
	else
		echo "Error: $BUILT_PRODUCTS_DIR does not exist."
		exit 1
	fi
fi

exit 0
