#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint sf_symbols.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'sf_symbols'
  s.version          = '0.6.0'
  s.summary          = 'Use SF Symbols on iOS and macOS.'
  s.description      = <<-DESC
Use SF Symbols on iOS and macOS, same as Image(systemName:) or UIImage(systemName:) in Swift.
                       DESC
  s.homepage         = 'https://github.com/LastMonopoly/sf_symbols'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'LastMonopoly' => 'LastMonopoly@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'sf_symbols/Sources/sf_symbols/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '12.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  s.resource_bundles = {'sf_symbols_privacy' => ['sf_symbols/Sources/sf_symbols/PrivacyInfo.xcprivacy']}
end
