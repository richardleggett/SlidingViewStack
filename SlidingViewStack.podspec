Pod::Spec.new do |s|
  s.name     = 'SlidingViewStack'
  s.version  = '0.9.3'
  s.license  = 'zlib'
  s.summary  = 'A depth-stacked collection of views that can be swiped/scrolled through, conforming to UITableView-style dataSource and delegate.'
  s.homepage = 'https://github.com/richardleggett/SlidingViewStack'
  s.author   = { 'Richard Leggett' => 'contact@richardleggett.co.uk' }
  s.source   = { :git => 'https://github.com/richardleggett/SlidingViewStack.git', :tag => '0.9.3' }
  s.platform = :ios
  s.source_files = 'SlidingViewStack/SlidingViewStack.{h,m}'
  s.requires_arc = true
  s.ios.deployment_target = '6.0'
  #not used...
  #s.resources = "SlidingViewStack/SlidingViewStack.bundle"
  #s.framework = 'QuartzCore'
end