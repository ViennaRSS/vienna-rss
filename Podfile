# Uncomment this line to define a global platform for your project
# platform :ios, '6.0'
platform :osx, '10.8'
source 'https://github.com/CocoaPods/Specs.git'

target 'Vienna' do
	pod 'MASPreferences', '~> 1.1.4'
	pod 'ASIHTTPRequest', '~> 1.8'
	pod 'FMDB', '~> 2.4'
	pod 'CDEvents'
	pod 'Sparkle'
end

target 'Vienna Tests' do
	pod 'FMDB', '~> 2.4'
	pod 'Sparkle'
	pod 'OCMock'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end
