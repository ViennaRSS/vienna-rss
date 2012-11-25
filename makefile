BUILD_DIR=build
PROJECT=Vienna.xcodeproj
TARGET=Vienna

default:
	xcodebuild -project $(PROJECT) -target $(TARGET) -configuration Development

release:
	xcodebuild -project $(PROJECT) -target "Archive and Prep for Upload" -configuration Deployment

clean:
	xcodebuild -target $(TARGET) -configuration Development clean
	xcodebuild -target $(TARGET) -configuration Deployment clean
