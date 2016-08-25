Gem::Specification.new do |s|
  s.author = 'Leonid Shevtsov'
  s.email = 'leonid@shevtsov.me'

  s.name = 'headless'
  s.version = '2.3.1'
  s.summary = 'Ruby headless display interface'
  s.license = 'MIT'

  s.description = <<-EOF
    Headless is a Ruby interface for Xvfb. It allows you to create a headless display straight from Ruby code, hiding some low-level action.
  EOF
  s.requirements = 'Xvfb'
  s.homepage = 'http://leonid.shevtsov.me/en/headless'

  s.files         = `git ls-files`.split("\n")

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'selenium-webdriver'
end
