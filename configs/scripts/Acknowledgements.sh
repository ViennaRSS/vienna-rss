#!/bin/sh

VIENNA_ACKNOWLEDGEMENTS_SOURCE="$SRCROOT/Acknowledgements.rtf"
VIENNA_ACKNOWLEDGEMENTS_PRODUCT="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/Acknowledgements.html"

if [ -e "$VIENNA_ACKNOWLEDGEMENTS_SOURCE" ] ; then
	echo "Converting Acknowledgements.rtf to Acknowledgements.html"
	if [ -e "$VIENNA_ACKNOWLEDGEMENTS_PRODUCT" ] ; then
		echo "Removing earlier Acknowledgements.html"
		rm -f "$VIENNA_ACKNOWLEDGEMENTS_PRODUCT"
	fi
	textutil -format rtf -convert html -output "$VIENNA_ACKNOWLEDGEMENTS_PRODUCT" "$VIENNA_ACKNOWLEDGEMENTS_SOURCE"
	echo "Converted Acknowledgements.rtf to Acknowledgements.html"
else
	echo "Error: The file Acknowledgements.rtf does not exist."
fi
