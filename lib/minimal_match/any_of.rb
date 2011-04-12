module MinimalMatch
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
    def not
      #toggle negated
      @negated = @negated ? false : true 
      self
    end
  end

  def any *args
    AnyOf.new(*args)
  end
end
#  vim: set ts=2 sw=2 tw=0 :
