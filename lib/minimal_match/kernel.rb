
# patches core classes to use minimal match

class Array
  include MinimalMatch::ArrayMethods
end

class Object
  include MinimalMatch::ToProxy
end

module Kernel
  module_function 
  def m *args, &block
    MinimalMatch.m *args, &block
  end

  def is_proxy? *args
    MinimalMatch::ProxyOperators.is_proxy? *args
  end
  
  def is_group? *args
    MinimalMatch::ProxyOperators.is_group? *args
  end

  def is_match_op? *args
    MinimalMatch::ProxyOperators.is_match_op? *args
  end

  Anything = MinimalMatch::Anything
  Begin = MinimalMatch::Begin
  End = MinimalMatch::End
end

