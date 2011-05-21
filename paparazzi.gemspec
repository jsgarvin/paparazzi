require File.expand_path('../lib/paparazzi/version', __FILE__)

Gem::Specification.new do |s|
  s.name = "admit_one"
  s.version = Paparazzi::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Jonathan S. Garvin"]
  s.email = ["jon@5valleys.com"]
  s.homepage = "https://github.com/jsgarvin/paparazzi"
  s.summary = %q{Rsync backup library with incremental snapshots.}
  s.description = %q{Rsync backup library that takes incremental hourly, daily, etc., snapshots.}

  s.add_dependency('admit_one', '>= 0.2.2')
    
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- test/*`.split("\n")
  s.require_paths = ["lib"]
end