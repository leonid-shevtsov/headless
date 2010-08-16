require 'rake'

spec = Gem::Specification.new do |s|
  s.author = 'Leonid Shevtsov'
  s.email = 'leonid@shevtsov.me'
  
  s.name = 'headless'
  s.version = '0.1.0'
  s.summary = 'Ruby headless display interface'

  s.description = <<-EOF
    Headless is a Ruby interface for Xvfb. It allows you to create a headless display straight from Ruby code, hiding some low-level action.
  EOF
  s.requirements = 'Xvfb'
  s.homepage = 'http://github.com/leonid-shevtsov/headless'

  s.files = FileList['lib/*.rb', '[A-Z]*'].to_a
  s.has_rdoc = true
end
