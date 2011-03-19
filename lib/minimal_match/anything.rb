require 'singleton'

module MinimalMatch
# Array::Anything.  it will always be equal to whatever you compare it to 
  class Anything
    include Singleton  #there can be only one
    include MatchMultiplying 
    def === who_cares
      true
    end

    def == who_cares
      true
    end

    def coerce other
      return self, other
    end
  end

  def anything
    Anything.instance()
  end
  module_function :anything
end
#  vim: set ts=2 sw=2 tw=0 :
