
# patches core classes to use minimal match

class Array
  include MinimalMatch::ArrayMethods
end

class Object
  include MinimalMatch::ToProxy
end

module Kernel
  module_function 
  def m *args
    MinimalMatch.m *args
  end

  def mg arg
    MinimalMatch.mg arg
  end

  def is_proxy? *args
    MinimalMatch.is_proxy? *args
  end
  
  def is_group? *args
    MinimalMatch.is_group? *args
  end

  def is_match_op? *args
    MinimalMatch.is_match_op? *args
  end

  Anything = MinimalMatch::Anything
  Begin = MinimalMatch::Begin
  End = MinimalMatch::End
end

