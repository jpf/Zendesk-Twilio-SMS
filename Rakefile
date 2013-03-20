require 'rubygems'
require 'rake'
require 'rspec/core/rake_task'

desc "Run all tests with RCov"
RSpec::Core::RakeTask.new('spec:rcov') do |spec|
  spec.pattern = 'spec/**/*.rb'
  spec.rcov = true
  spec.rcov_opts = ['--exclude', 'spec']
end

RSpec::Core::RakeTask.new('spec') do |spec|
  spec.pattern = 'spec/**/*.rb'
  spec.rspec_opts = ['--format', 'documentation', '--colour']
end
