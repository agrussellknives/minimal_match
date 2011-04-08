
# patches core classes to use minimal match

class Array
  include MinimalMatch
end

module Kernel
  module_function 
  def m *args
    MinimalMatch.m *args
  end

  def ma *args
    MinimalMatch.any *args
  end
end

