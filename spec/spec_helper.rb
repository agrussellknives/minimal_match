$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'minimal_match'


# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  
end

require 'simplecov'
SimpleCov.start 


# this is just data to test the search on.  sexps work great for this
class Array
  include MinimalMatch
end

class Dummy
  include Enumerable
  def foo
    puts "bar"
  end

  def bar
    puts "foo"
  end
end

class Dumber
  include Enumerable
  def foo
    puts "bar"
  end

  def baz
    puts "foobile"
  end
end
