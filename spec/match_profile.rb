#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

# gotta turn this on to make the profiler work
RubyVM::InstructionSequence.compile_option = {
  :trace_instruction => true,
  :specialized_instruction => false
}

# performs simple profileing on the minimal_match gem
require 'profiler'
require 'minimal_match'

module Profile
  def profile
    Profiler__::stop_profile
    Profiler__::start_profile
    yield
    Profiler__::print_profile(STDOUT)
  end
  module_function :profile
end

class Array
  include MinimalMatch
end

puts "Obvious operations:"
Profile.profile do
  [1,2,3] =~ [1,2,3]
  ['a','b','c'] =~ ['a','b','c']
  [{:foo => :bar},{:baz => :bab}] =~ [{:foo => :bar},{:baz => :bab}]
  [1,2,3] =~ [3,2,1]
  [1,2,3,4,5] =~ [1,2,3]
  [1,2,3] =~ [1,2,3,4,5]
  [1,2,3,4,5] =~ [3,4]
  [1,2,3,4,5] =~ [3,5]
  [1,2,3,4,5] =~ [4,5,6]
  [1,[2,3,[4,5]]] =~ [1,[2,3,[4,5]]]
  [1,[2,[4]]] =~ [1,[2,[4]]]
  # match pattern is too specific
  [1,[2,[4]]] =~ [1,[2,3,[4]]]
  #because position two of the array is not [3,4]
  [1,2,[3,4,5]] =~ [1,[3,4]]
end

puts "Anything operations:"
Profile.profile do
  [1,2,3,4,5] =~ [MinimalMatch.anything,2,3,4,5]
  [1,2,3,4,5] =~ [MinimalMatch.anything]
  [1,2,3,4,5] =~ [MinimalMatch.anything,3]
  [1,[2,3,[4,5,6]]] =~ [1,[2,MinimalMatch.anything,[4,MinimalMatch.anything,6]]]
  [1,2,[3,4,5]] =~ [1,MinimalMatch.anything,[3,4]]
end

