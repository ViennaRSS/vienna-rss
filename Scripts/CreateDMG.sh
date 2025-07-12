#!/bin/bash

. "${SOURCE_ROOT}/Build/Post-archive-exports.txt"

dmgsource="${PROJECT_DERIVED_FILE_DIR}/viennadist/"
rawdmgfile="${PROJECT_DERIVED_FILE_DIR}/Vienna${N_VCS_TAG}.raw.dmg"    # Temporary uncompressed DMG file
finaldmgfile="${PROJECT_DERIVED_FILE_DIR}/Vienna${N_VCS_TAG}.dmg"      # Final compressed DMG file

rm -rf ${dmgsource}
mkdir -p ${dmgsource}

# Copy the app cleanly
xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE_PATH" -exportPath ${dmgsource}

volname="Vienna ${V_VCS_TAG}"
echo Running Pack and Copy Script...
echo Creating volume...
hdiutil create ${rawdmgfile} -ov -volname "${volname}" -format UDRW -srcfolder ${dmgsource}

mounteddmgfile="/Volumes/${volname}";   # Mounted DMG file for writing
diskutil eject "${mounteddmgfile}"  # Just to be sure to avoid any confusion

echo Mounting volume...
device=$(hdiutil attach ${rawdmgfile} | awk 'NR==1{print $1}')

pushd "${mounteddmgfile}"

echo Creating supporting files...
ln -s "/Applications" .
cp "${SRCROOT}/Scripts/Resources/DS_Store" .DS_Store
rm -rf .fseventsd

popd

echo Unmounting volume...
hdiutil detach ${device}

echo Compressing volume...
hdiutil convert -ov ${rawdmgfile} -format ULFO -o ${finaldmgfile}

rm -rf ${dmgsource}
rm ${rawdmgfile}

exit 0
