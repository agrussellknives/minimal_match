module MinimalMatch
# Array::Anything.  it will always be equal to whatever you compare it to 
  class Anything < MinimalMatchObject
    include MatchMultiplying
    # it matches anything OTHER than another minimal matchobject
    def === who_cares
      # i think there is a prettier way to do this with coerce
      # basically Anything is equal to anything OTHER than a different
      # minimal match object
      who_cares.kind_of? MinimalMatchObject ? false : true
    end
    alias :== :===

    def to_s
      "<ANYTHING>"
    end
    alias :inspect :to_s

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
