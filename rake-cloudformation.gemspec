# ex: syntax=ruby ts=2 sw=2 si et

Gem::Specification.new do |gem|
  gem.authors       = [ 'Nate Riffe']
  gem.email         = 'inkblot@movealong.org'
  gem.description   = 'Library functions for defining tasks to start AWS CloudFormation stacks using rake'
  gem.summary       = 'Start AWS CloudFormation stacks with rake'
  gem.homepage      = 'https://github.com/inkblot/rake-cloudformation.git'

  gem.files         = `git ls-files`.split($\)
  gem.name          = 'rake-cloudformation'
  gem.require_paths = [ 'lib' ]
  gem.version       = '3'

  gem.add_runtime_dependency 'aws-sdk', '~> 2'
end
