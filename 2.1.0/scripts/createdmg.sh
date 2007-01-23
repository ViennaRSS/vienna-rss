#!/bin/bash

volsize=13.0m;              # Initial size of DMG volume

# Check command line usage
if [ "$1" == "" ]; then
{
    echo "Usage: createdmg.sh [full build number]"
    echo ""
    exit 0;
}
fi;

# Make sure we're in the right folder
if [ ! -d "build/Deployment" ]; then
{
    echo "Error: No build/Deployment folder found"
    echo ""
    exit 0;
}
fi;

rawdmgfile=~/Vienna$1.raw.dmg;    # Temporary uncompressed DMG file
finaldmgfile=~/Vienna$1.dmg;      # Final compressed DMG file

# Remove any existing files
if [ -e $rawdmgfile ]; then
{
    rm $rawdmgfile
}
fi;
if [ -e $finaldmgfile ]; then
{
    rm $finaldmgfile
}
fi;

echo Running Pack and Copy Script...
echo Creating volume...
hdiutil create -size $volsize -fs HFS+ -volname "Vienna $1" $rawdmgfile

echo Mounting volume...
hdiutil mount $rawdmgfile

mounteddmgfile="/Volumes/Vienna $1";   # Mounted DMG file for writing

echo Copying Vienna and supporting files...
mkdir "$mounteddmgfile/.background"
cp "dmgfiles/Applications" "$mounteddmgfile"
cp "dmgfiles/DS_Store" "$mounteddmgfile/.DS_Store"
cp "dmgfiles/DMGBackground.png" "$mounteddmgfile/.background/DMGBackground.png"
cp -RL "build/Deployment/Vienna.app" "$mounteddmgfile"

echo Unmounting volume...
hdiutil unmount "$mounteddmgfile"

echo Compressing volume...
hdiutil convert -format UDCO -o $finaldmgfile $rawdmgfile
rm $rawdmgfile

echo Done!
echo ""

