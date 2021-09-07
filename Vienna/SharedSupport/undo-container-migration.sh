#!/bin/sh
#
#  undo-container-migration.sh
#  Vienna
#
#  Copyright 2021-2024 Eitot
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  https://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

LIBRARY="$HOME/Library"
BUNDLE_ID='uk.co.opencommunity.vienna2'
CONTAINER="$LIBRARY/Containers/$BUNDLE_ID"
CONTAINER_LIBRARY="$CONTAINER/Data/Library"

set -e

if [ ! -d "$CONTAINER" ]
then
    printf 'No sandbox container found for Vienna\n' >&2
    exit 1
fi

if [ -n "$(killall -s Vienna 2>/dev/null)" ]
then
    printf 'Please quit Vienna and try again\n' >&2
    exit 1
fi

printf 'This script attempts to undo the container migration. Use this only to '
printf 'revert to an older version of Vienna that does not support sandboxing. '
printf 'Please make sure that Vienna is not opened during this process.\n'

tput bold
printf 'Are you sure you want to do this? [y/N] '
tput sgr0
read -r
if ! printf '%s' "$REPLY" | grep -q -E '^[Yy]$'
then
    exit 1
fi

# Configure ditto to use verbose mode and abort if encountering a fatal error.
alias ditto='ditto -v'
export DITTOABORT=1

# User scripts are located in ~/Library/Application Scripts/<bundle ID> instead
# of the sandbox container when sandboxing is enabled. Without sandboxing, they
# are located in ~/Library/Scripts/Applications/<app name>. A symlink was added
# at that location as a result of the automatic migration.
if [ -L "$LIBRARY/Scripts/Applications/Vienna" ]
then
    unlink "$LIBRARY/Scripts/Applications/Vienna" \
    && printf 'Unlinked symlink %s\n' "$LIBRARY/Scripts/Applications/Vienna"
fi

if [ -d "$LIBRARY/Application Scripts/$BUNDLE_ID" ]
then
    ditto "$LIBRARY/Application Scripts/$BUNDLE_ID" \
          "$LIBRARY/Scripts/Applications/Vienna" \
    && rm -r "$LIBRARY/Application Scripts/$BUNDLE_ID"
fi

if [ -d "$CONTAINER_LIBRARY/WebKit/Databases/___IndexedDB" ]
then
    ditto "$CONTAINER_LIBRARY/WebKit/Databases/___IndexedDB" \
          "$LIBRARY/WebKit/Databases/___IndexedDB/$BUNDLE_ID" \
    && rm -r "$CONTAINER_LIBRARY/WebKit/Databases/___IndexedDB"
fi

if [ -d "$CONTAINER_LIBRARY/WebKit" ]
then
    ditto "$CONTAINER_LIBRARY/WebKit" "$LIBRARY/WebKit/$BUNDLE_ID"
fi

if [ -d "$CONTAINER_LIBRARY/Saved Application State/$BUNDLE_ID.savedState" ]
then
    ditto "$CONTAINER_LIBRARY/Saved Application State/$BUNDLE_ID.savedState" \
          "$LIBRARY/Saved Application State/$BUNDLE_ID.savedState"
fi

# Preferences are not explicitely declared in the migration manifest file; the
# behaviour is implicit.
if [ -f "$CONTAINER_LIBRARY/Preferences/$BUNDLE_ID.plist" ]
then
    ditto "$CONTAINER_LIBRARY/Preferences/$BUNDLE_ID.plist" \
          "$LIBRARY/Preferences/$BUNDLE_ID.plist"
fi

# The location of cookies files of non-sandboxed applications changed from
# ~/Library/Cookies to ~/Library/HTTPStorages as of macOS 11 (and probably
# Safari 14).
MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR_VERSION="${MACOS_VERSION%%.*}"

if [ "$MACOS_MAJOR_VERSION" -ge 11 ] || [ -d "$LIBRARY/HTTPStorages" ]
then
    if [ -f "$CONTAINER_LIBRARY/Cookies/Cookies.binarycookies" ]
    then
        ditto "$CONTAINER_LIBRARY/Cookies/Cookies.binarycookies" \
              "$LIBRARY/HTTPStorages/$BUNDLE_ID.binarycookies"
    fi
else
    if [ -f "$CONTAINER_LIBRARY/Cookies/Cookies.binarycookies" ]
    then
        ditto "$CONTAINER_LIBRARY/Cookies/Cookies.binarycookies" \
              "$LIBRARY/Cookies/$BUNDLE_ID.binarycookies"
    fi
fi

if [ -d "$CONTAINER_LIBRARY/HTTPStorages/$BUNDLE_ID" ]
then
    ditto "$CONTAINER_LIBRARY/HTTPStorages/$BUNDLE_ID" \
          "$LIBRARY/HTTPStorages/$BUNDLE_ID"
fi

if [ -d "$CONTAINER_LIBRARY/Application Support/Vienna" ]
then
    ditto "$CONTAINER_LIBRARY/Application Support/Vienna" \
          "$LIBRARY/Application Support/Vienna"
fi

# The Sources subdirectory was moved from Library/Application Support to
# Library/Caches.
if [ -d "$CONTAINER_LIBRARY/Caches/$BUNDLE_ID/Sources" ]
then
    ditto "$CONTAINER_LIBRARY/Caches/$BUNDLE_ID/Sources" \
          "$LIBRARY/Application Support/Vienna/Sources" \
    && rm -r "$CONTAINER_LIBRARY/Caches/$BUNDLE_ID/Sources"
fi

# The WebKit subdirectory in Library/Caches used to be located within the app's
# caches directory (Library/Caches/<bundle ID>/WebKit).
if [ -d "$CONTAINER_LIBRARY/Caches/WebKit" ]
then
    ditto "$CONTAINER_LIBRARY/Caches/WebKit" "$LIBRARY/Caches/$BUNDLE_ID/WebKit"
fi

if [ -d "$CONTAINER_LIBRARY/Caches/$BUNDLE_ID" ]
then
    ditto "$CONTAINER_LIBRARY/Caches/$BUNDLE_ID" "$LIBRARY/Caches/$BUNDLE_ID"
fi

osascript -e "tell application \"Finder\" to delete POSIX file \"$CONTAINER\"" \
1>/dev/null && printf 'Moved %s to Trash\n' "$CONTAINER"
