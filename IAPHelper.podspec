Pod::Spec.new do |s|

  s.name         = "IAPHelper"
  s.version      = "1.0.7"
  s.summary      = "In App Purchases Helper."
  s.homepage     = "https://github.com/saturngod/IAPHelper"
  s.license  = "MIT"
  s.author       = { "saturngod" => "saturngod@gmail.com" }
  s.requires_arc = true
  s.platform     = :ios, '7.0'
  s.source       = { :git => "https://github.com/thanhtrdang/IAPHelper.git", :branch => "master" }
  s.source_files = "IAPHelper/Library/*.{h,m}"
  s.public_header_files = "IAPHelper/Library/*.h"
  s.framework    = "StoreKit"
  s.dependency     "FXKeychain"

end
