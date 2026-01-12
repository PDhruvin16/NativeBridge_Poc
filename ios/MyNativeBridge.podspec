require "json"

package = JSON.parse(File.read(File.join(__dir__, "../package.json")))

Pod::Spec.new do |s|
  s.name         = "MyNativeBridge"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = "React Native Camera Object Detection"

  s.homepage     = "https://github.com/PDhruvin16/NativeBridge_Poc"
  s.license      = { :type => "MIT" }
  s.authors      = { "Your Name" => "your@email.com" }

  s.platforms    = { :ios => "13.4" }  # Changed from 13.0
  s.source       = { :git => "", :tag => "#{s.version}" }

  s.source_files = "*.{h,m,mm,swift}"
  s.public_header_files = "*.h"
  
  s.dependency "React-Core"
  
  s.frameworks = "AVFoundation", "Vision", "CoreML"
  
  s.swift_version = "5.0"
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end