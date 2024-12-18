Pod::Spec.new do |s|
  s.name             = 'LogBird'
  s.version          = '1.0.0'
  s.summary          = 'LogBird is a powerful yet simple logging library for Swift, designed to provide flexible and efficient console logging.'
  s.homepage         = 'https://github.com/javiermanzo/LogBird'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Javier Manzo' => 'javier.r.manzo@gmail.com' }
  s.source           = { :git => 'https://github.com/javiermanzo/LogBird.git', :tag => s.version.to_s }
  s.social_media_url = 'https://www.linkedin.com/in/javiermanzo/'
  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'
  s.source_files = 'Sources/Harbor/**/*'
end
