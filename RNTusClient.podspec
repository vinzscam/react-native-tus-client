require 'json'
package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "RNTusClient"
  s.version      = package['version']
  s.summary      = package["description"]
  s.requires_arc = true
  s.license      = package["license"]
  s.homepage     = 'https://github.com/vinzscam/react-native-tus-client'
  s.author       = { "Vincenzo Scamporlino" => "vincenzo@scamporlino.it" }
  s.source       = { :git => "https://github.com/vinzscam/react-native-tus-client", :tag => 'v#{s.version}'}
  s.source_files = 'ios/*.{h,m}'

  s.ios.deployment_target = '8.0'

  s.dependency 'React-Core'
  s.dependency 'TUSKit'
end
