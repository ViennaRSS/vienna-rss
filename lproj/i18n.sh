#  Copyright (c) 2003 David Kocher. All rights reserved.
#  http://cyberduck.ch/
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  Bug fixes, suggestions and comments should be sent to:
#  dkocher@cyberduck.ch

#!/bin/bash

base_language="en.lproj"

usage() {
	echo ""
	echo "Show localization status using polyglot"
	echo "    Usage: i18n.sh [-l <language>] --status"
	echo "Initialize new localization project"
	echo "    Usage: i18n.sh [-l <language>] --init"
	echo "Update localization(s), use [--force] to ignore previous custom layout in localized NIBs"
	echo "    Usage: i18n.sh [-l <language>] [-n <nib>] [--force] --update"
	echo ""
	echo "<language> must be ja.lproj, fr.lproj, es.lproj, ..."
	echo "<nib> must be Preferences.nib, Main.nib, ..."
	echo ""
}

init() {
	mkdir -p $language
	for nibfile in `ls $base_language | grep .nib | grep -v ~.nib | grep -v .bak`; do
		echo "Copying $nibfile"
		nib=`basename $nibfile .nib`
		cp -R $base_language/$nibfile $language/$nibfile
		rm -rf $language/$nibfile/.svn
		nibtool --localizable-strings $language/$nibfile > $language/$nib.strings
	done
	cp $base_language/Localizable.strings $language/
	cp $base_language/InfoPlist.strings $language/
}

open() {
	nib=`basename $nibfile .nib`
	if [ "$language" = "all" ] ; then
	{
		for lproj in `ls . | grep lproj`; do
			if [ $lproj != $base_language ]; then
				echo "*** Opening $lproj/$nib.strings"
				/usr/bin/open $lproj/$nib.strings
			fi;
		done;
	}
	else
	{
		echo "*** Opening $language/$nib.strings"
		/usr/bin/open $language/$nib.strings
	}
	fi;
}

status() {
	if [ "$language" = "all" ] ; then
	{
		for lproj in `ls . | grep lproj`; do
			language=$lproj;
			if [ $language != $base_language ]; then
				echo "*** Status of $language Localization...";
				/usr/local/bin/polyglot -b `basename $base_language .lproj` -l `basename $language .lproj` .
			fi;
		done;
	}
	else
	{
		echo "*** Status of $language Localization...";
		/usr/local/bin/polyglot -b `basename $base_language .lproj` -l `basename $language .lproj` .
	}
	fi;
}

nib() {
	#Changes to the .strings has precedence over the NIBs
    updateNibFromStrings;
	#Update the .strings with new values from NIBs
    udpateStringsFromNib;
}

updateNibFromStrings() {
	if (`test -f $language/$nib.strings`); then
	{
		if (`test -d $language/$nibfile`); then
		{
			rm -rf $language/$nibfile.bak
	    	mv $language/$nibfile $language/$nibfile.bak
		
		    if($force == true); then
			{
				# force update
				echo "*** Updating $nib... (force) in $language..."
				nibtool --write $language/$nibfile \
					--dictionary $language/$nib.strings $base_language/$nibfile
			}
		    else
			{
				# incremental update
				echo "*** Updating $nib... (incremental) in $language..."
				nibtool --write $language/$nibfile \
					--incremental $language/$nibfile.bak \
					--dictionary $language/$nib.strings $base_language/$nibfile
			}
		    fi;
		
			if (`test -d $language/$nibfile.bak`); then
		    	cp -R $language/$nibfile.bak/.svn $language/$nibfile/.svn
				rm -rf $language/$nibfile.bak
			fi;
		}
		fi;
	}
	fi;
}

udpateStringsFromNib() {
	if (`test -d $language/$nibfile`); then
	{
		echo "*** Updating $nib.strings in $language..."
    	nibtool --previous $base_language/$nibfile \
            --incremental $language/$nibfile \
            --localizable-strings $base_language/$nibfile > $language/$nib.strings
	}
	fi;
}

update() {
	if [ "$language" = "all" ] ; then
	{
		echo "*** Updating all localizations...";
		for lproj in `ls . | grep lproj`; do
			language=$lproj;
			if [ $language != $base_language ]; then
			{
				echo "*** Updating $language Localization...";
				if [ "$nibfile" = "all" ] ; then
					echo "*** Updating all NIBs...";
					for nibfile in `ls $language | grep .nib | grep -v ~.nib | grep -v .bak`; do
						nib=`basename $nibfile .nib`
						nibtool --localizable-strings $base_language/$nibfile > $base_language/$nib.strings
						nib;
					done;
				fi;
				if [ "$nibfile" != "all" ] ; then
						nib=`basename $nibfile .nib`
						nibtool --localizable-strings $base_language/$nibfile > $base_language/$nib.strings
						nib;
				fi;
			}
			fi;
		done;
	}
	else
	{
		echo "*** Updating $language Localization...";
		if [ "$nibfile" = "all" ] ; then
			echo "*** Updating all NIBs...";
			for nibfile in `ls $language | grep .nib | grep -v ~.nib | grep -v .bak`; do
				nib=`basename $nibfile .nib`;
				nibtool --localizable-strings $base_language/$nibfile > $base_language/$nib.strings
				nib;
			done;
		fi;
		if [ "$nibfile" != "all" ] ; then
		{
			nib=`basename $nibfile .nib`;
			nibtool --localizable-strings $base_language/$nibfile > $base_language/$nib.strings
			nib;
		}
		fi;
	}
	fi;
}

language="all";
nibfile="all";
force=false;

while [ "$1" != "" ] # When there are arguments...
	do case "$1" in 
			-l | --language)
				shift;
				language=$1;
				echo "Using Language:$language";
				shift;
			;;
			-n | --nib) 
				shift;
				nibfile=$1;
				echo "Using Nib:$nibfile";
				shift;
			;;
			-f | --force) 
				force=true;
				shift;
			;;
			-h | --help) 
				usage;
				exit 0;
				echo "*** DONE. ***";
			;; 
			-i | --init)
				echo "Init new localization...";
				init;
				echo "*** DONE. ***";
				exit 0;
			;; 
			-s | --status)
				echo "Status of localization...";
				status;
				echo "*** DONE. ***";
				exit 0;
			;; 
			-u | --update)
				echo "Updating localization...";
				update;
				echo "*** DONE. ***";
				exit 0;
			;;
			-o | --open)
				echo "Opening localization .strings files...";
				open;
				echo "*** DONE. ***";
				exit 0;
			;; 
			*)  
				echo "Option [$1] not one of  [--status, --update, --open, --init]"; # Error (!)
				exit 1
			;; # Abort Script Now
	esac;
done;

usage;
