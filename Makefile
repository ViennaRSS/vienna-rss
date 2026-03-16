PROJECT=Vienna.xcodeproj
LOCALES=cs da de en-AU en-GB es eu fr gl it ja ko lt nl pt-BR pt ru sv tr uk zh-Hans zh-Hant

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

localize:
	for locale in $(LOCALES); do \
		xcodebuild -importLocalizations -project $(PROJECT) \
		-localizationPath Localizations/$${locale}.xliff \
		-disableAutomaticPackageResolution; \
	done
