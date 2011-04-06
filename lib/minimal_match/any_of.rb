module MinimalMatch
  class AnyOf < MinimalMatchObject
    include MatchMultiplying
    
    def initialize(*args)
      @match_array = []
      @match_array << args.each { |i| MatchProxy.new i }
    end

    def method_missing meth, *args
      nil
    end

    def class
      AnyOf
    end
    
    def inspect
      "#{self.class}:#{@match_array.to_s}"
    end

    def === obj
      ret = @negated ? false : true
      @match_array.each do |m|
        return ret if m === obj
      end
      !(ret)
    end

    #negated class
    def !
      @negated = true
    end
  end

  def any_of *args
    AnyOf.new(*args)
  end
  module_function :any_of
end
#  vim: set ts=2 sw=2 tw=0 :
