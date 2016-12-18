lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = 'spot_build'
  gem.version       = '0.0.1'
  gem.authors       = ['Patrick Robinson']
  gem.email         = []
  gem.description   = 'Helps manage Buildkite Agents running on EC2 Spot instances'
  gem.summary       = gem.description
  gem.homepage      = 'https://github.com/envato/spot_build'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'buildkit', '~> 0.4'
end