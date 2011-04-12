module MinimalMatch
  
  class MatchProxy < AbstractMatchProxy 

    def initialize val
      unless is_proxy? val
        if val.is_a? ::Array 
          val = AnyOf.new(*val)
        end
      end
      super(val.class)
      # pass an array into match proxy to create a
      # group
      while is_proxy? val
        val = val.comp_obj
      end
      @comp_obj = val
      self
    end

    #specialcased
    def nil?
      @comp_obj.nil? ? true : false
    end

    def is_group?
      false
    end

    def to_s
      if @comp_obj.kind_of? AnyOf and @comp_obj.negated?
        s = @comp_obj.to_s 
        s = s.split('.')
        s = "m(#{s[0]}).#{s[1]}"
      else
        s = "m(#{@comp_obj.to_s})"
      end
      s
    end
    
    def inspect
      "<#{@comp_obj.inspect} : MatchProxy>"
    end

    def coerce arg
      arg_equiv = is_proxy?(arg) ? arg.comp_obj : arg
      return self, arg_equiv
    end

    def method_missing meth, *args
      puts "sent #{meth} with #{args}"
      res = @comp_obj.__send__ meth, *args
      MatchProxy.new(res)
    end
  end

  class MatchProxyGroup < AbstractMatchProxy 
    
    attr_reader :bind_name
    def initialize *vals
      super(MatchProxyGroup)
      @comp_obj = vals.collect do |v| 
        if is_proxy? v or is_match_op? v then v else MatchProxy.new(v) end 
      end
      @bind_name = nil
      self
    end
    
    def inspect
      str = "MatchProxyGroup of ("
      str << @comp_obj.collect do |i|
        i.inspect
      end.join(",")
      str << ")"
      str
    end
    
    def is_group?
      true
    end

    def bind name = nil
      @bind_name = name
    end

    def to_s
      str = "m("
      str << @comp_obj.collect do |i|
        if i.is_group?
          i.to_s
        elsif i.comp_obj.is_a? ::Symbol
          ":#{i.comp_obj.to_s}"
        else
          i.comp_obj.to_s
        end
      end.join(',')
      str << ")"
    end

    # not sure if that's the best way to do this or not
    def to_ary
      @comp_obj
    end
    
    def method_missing meth, *args
      $stdout.puts "distributing method call #{meth} to match_obj group"
      v = @comp_obj.map do |c|
        c.__send__ meth, *args
      end
      MatchProxyGroup.new(v)
    end
  end
end
#  vim: set ts=2 sw=2 tw=0 :
