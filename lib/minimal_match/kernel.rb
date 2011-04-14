
# patches core classes to use minimal match

class Array
  include MinimalMatch
end

module Kernel
  module_function 
  def m *args
    MinimalMatch.m *args
  end

  Anything = MinimalMatch::Anything
  Begin = MinimalMatch::Begin
  End = MinimalMatch::End
end

