Pod::Spec.new do |s|
  s.name             = 'PhotoEditor'
  s.version          = '0.9.8'
  s.summary          = 'Photo Editor supports drawing, writing text and adding stickers and emojis'
 
  s.description      = <<-DESC
Photo Editor supports drawing, writing text and adding stickers and emojis
with the ability to scale and rotate objects
                       DESC
 
  s.homepage         = 'https://github.com/goreste/photo-editor'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Mohamed Hamed' => 'mohamed.hamed.ibrahem@gmail.com' }
  s.source           = { :git => 'https://github.com/goreste/photo-editor.git', :tag => s.version.to_s }
 
  s.ios.deployment_target = '9.0'
  s.source_files = "PhotoEditor/*"
  s.resources = "PhotoEditor/*.{png,jpeg,jpg,storyboard,xib,ttf}"

  s.default_subspec = "Core"

  s.subspec "Core" do |ss|
    ss.dependency "Gifu"
    ss.dependency "PromiseKit"
  end
end
