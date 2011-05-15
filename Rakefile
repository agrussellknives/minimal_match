$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'lib/minimal_match/version'

require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'
require 'jeweler'

Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "minimal_match"
  gem.homepage = "http://github.com/agrussellknives/minimal_match"
  gem.license = "MIT"
  gem.summary = %Q{Provides basic pattern matching on Ruby Arrays}
  gem.description = %Q{EXTREMELY basic pattern matching on Ruby Arrays.  Useful when you don't need the full power of
    something like MatchMaker - you just want to match some arrays.}
  gem.email = "stephenp@agrussell.com"
  gem.authors = ["Stephen Prater (A.G. Russell Knives)"]
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
  gem.version == MinimalMatch::Version::STRING
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:spec_with_report) do |spec|
  spec.fail_on_error = false
  spec.skip_bundler = true
  spec.pattern = FileList['spec/**/*_spec.rb']
  spec.rspec_opts = "--format html --out report/test_report.html"
end

task :report do
  Dir.mkdir "report" unless File.exists? "report"
  Dir.mkdir "report/profile" unless File.exists? "report/profile"
  File.open "report/index.html","w" do |f|
    f.write <<-HTML
      <html>
        <body>
          <h1> Status Report </h1>
          <a href="coverage/index.html"> Coverage </a>
          <a href="profile/profile.html"> Speed Profile </a>
          <a href="test_report.html"> Test Report </a>
        </body>
      </html>
    HTML
  end
  ENV["REPORT"] = "1" 
  Rake::Task[:spec_with_report].invoke
  ENV["REPORT"] = ""
end 

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "minimal_match #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
