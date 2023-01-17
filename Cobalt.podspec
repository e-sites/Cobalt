Pod::Spec.new do |s|
  s.name         = "Cobalt"
  s.version      = "7.3.4"
  s.author       = { "Bas van Kuijck" => "bas@e-sites.nl" }
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.homepage     = "http://www.e-sites.nl"
  s.summary      = "_THE_ E-sites Swift iOS API Client used for standard restful API's with default support for OAuth2."
  s.source       = { :git => "https://github.com/e-sites/Cobalt.git", :tag => "v#{s.version}" }
  s.source_files = "Sources/*.h"
  s.platform     = :ios, '10.0'
  s.requires_arc  = true
  s.swift_versions = [ '5.0', '5.1', '5.2', '5.3' ]

  s.subspec 'Core' do |ss|
    ss.source_files = "Sources/Core/**/*.{h,swift}"
  	ss.dependency 'Alamofire', '> 5.0'
  	ss.dependency 'SwiftyJSON'
    ss.dependency 'RxSwift'
    ss.dependency 'RxCocoa'
    ss.dependency 'KeychainAccess'
    ss.dependency 'Logging'
  end

  s.subspec 'Cache' do |ss|
    ss.source_files = "Sources/Cache/**/*.{h,swift}"
    ss.dependency 'Cobalt/Core'
  end

  s.default_subspec = 'Core'
end
