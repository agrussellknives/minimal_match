module MinimalMatch
  #special literals
  class AnyOf < MinimalMatchObject
    def initialize(*args)
      super()
      @match_array = []
      @match_array.concat(args.each { |i| MatchProxy.new i })
    end

    def to_s
      str = "["
      str << @match_array.collect do |i|
        i.to_s
      end.join(",")
      str << "]"
      str = "m(#{str}).not" if @negated
      str
    end
    
    def inspect
      str = self.class.to_s.split('::')
      str[-1] =str[-1].insert(0,"Not") if @negated
      str = str.join('::')
      "#{str}:#{@match_array.to_s}"
    end
    

    def === obj
      ret = @negated ? false : true
      @match_array.each do |m|
        return ret if m === obj
      end
      !(ret)
    end

    def negated?
      @negated
    end

    #negated class
    # there is no ! operator because we're using
    # it for non-greedy
    def not
      #toggle negated
      @negated = @negated ? false : true 
      self
    end
  end

# Array::Anything.  it will always be equal to whatever you compare it to 
  class AnythingClass < MinimalMatchObject
    # it matches anything OTHER than another minimal matchobject
    include ::Singleton

    def === who_cares
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
  end

  class MarkerObject < MinimalMatchObject
    # abstract position marker
    include ::Singleton
    
    def ===
      false
    end

    def to_s
      #memoize the string value after it's calculated
      @s_val ||= lambda { self.class.to_s.gsub("Class",'') }.call
    end

    def inspect
      self.class
    end

    private :initialize
  end

  class EndClass < MarkerObject
    def _compile idx
      [:lit, Sentinel]
    end
  end
  class BeginClass < MarkerObject; end

  # you can't access the array "post" from ruby code
  # so you need this to know when you're at the end of
  # the array
  class SentinelClass < MarkerObject
    def === cmp
      cmp.equal? self 
    end
    
    def _compile idx
      raise RuntimeError, "called compile on internal object. eep, mommy."
    end
  end
 
  Anything = MinimalMatch::AnythingClass.instance
  End = MinimalMatch::EndClass.instance
  Begin = MinimalMatch::BeginClass.instance
  Sentinel = MinimalMatch::SentinelClass.instance


end
#  vim: set ts=2 sw=2 tw=0 :
