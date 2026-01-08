require "json"

package = JSON.parse(File.read(File.join(__dir__, "../package.json")))

Pod::Spec.new do |s|
  s.name         = "MyNativeBridge"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = "React Native Camera Object Detection"
  
  s.homepage     = "https://github.com/yourusername/react-native-my-native-bridge"
  s.license      = { :type => "MIT" }
  s.authors      = { "Your Name" => "your@email.com" }
  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => "", :tag => "#{s.version}" }

  s.source_files = "*.{h,m,mm,swift}"
  
  s.dependency "React-Core"
  
  s.frameworks = "AVFoundation", "Vision", "CoreML"
end