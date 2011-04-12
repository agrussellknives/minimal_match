require 'singleton'

module MinimalMatch
# Array::Anything.  it will always be equal to whatever you compare it to 
  class AnythingClass < MinimalMatchObject
    include MatchMultiplying
    # it matches anything OTHER than another minimal matchobject
   
    def === who_cares
      # i think there is a prettier way to do this with coerce
      # basically Anything is equal to anything OTHER than a different
      # minimal match objecA
      if who_cares.kind_of? MinimalMatchObject and not who_cares.eql? self
        false
      else
        true
      end
    end
    alias :== :===

    def to_s
      "Anything"
    end
    alias :inspect :to_s

    def comp_obj
      self
    end
  end
  AnythingClass.__send__ :include, Singleton

  def anything
    AnythingClass.instance()
  end
  module_function :anything
end
#  vim: set ts=2 sw=2 tw=0 :
