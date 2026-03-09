PROJECT=Vienna.xcodeproj

default:
	xcodebuild -project $(PROJECT) -scheme Vienna archive
	xcodebuild -project $(PROJECT) -target Notarization -configuration Deployment
	xcodebuild -project $(PROJECT) -scheme Deployment

release:
	xcodebuild -project $(PROJECT) -scheme Vienna archive
	xcodebuild -project $(PROJECT) -target Notarization -configuration Deployment
	xcodebuild -project $(PROJECT) -scheme Deployment

development:
	xcodebuild -project $(PROJECT) -scheme Vienna -configuration Development

clean:
	xcodebuild -project $(PROJECT) -scheme Vienna -configuration Development clean
	xcodebuild -project $(PROJECT) -scheme Vienna -configuration Deployment clean
	rm -fr Build
