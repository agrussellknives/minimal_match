module MinimalMatch
  
  class MatchProxy < AbstractMatchProxy 

    def initialize val
      if not is_proxy? val
        # pass a single array into a matchproxy
        # construction to create a "character class"
        if val.is_a? ::Array 
          val = AnyOf.new(*val)
        end
        super(val.class)
      else
        super(val.comp_obj.class)
        val = val.comp_obj
      end
      @comp_obj = val
      self
    end

    #specialcased
    def nil?
      @comp_obj.nil? ? true : false
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
      puts "sent #{meth} with #{args} from #{__sender__}::#{__caller__}"
      res = @comp_obj.__send__ meth, *args
      if is_proxy? res then res else MatchProxy.new(res) end # return a new proxy object
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
      @is_group = true
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
    
    def bind name = nil
      @bind_name = name
    end

    def to_s
      str = "m("
      str << @comp_obj.collect do |i|
        if is_group? i
          i.to_s
        elsif i.comp_obj.is_a? ::Symbol #yeahhh
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

    def _compile bind_index = nil
      puts "compile with #{bind_index} from #{__sender__}::#{__caller__}"
      run = [[:save, @bind_name || bind_index ]] # replace this with bind_index
      @comp_obj.each_with_index.each_with_object(run) do |(mi, idx), memo|
        $stdout << <<-INFO
          memo : #{memo.to_s}
          mi : #{mi.to_s}
          idx : #{idx.to_s}
        INFO
        memo << mi.compile(bind_index+idx+1)
      end
      run << [:save, @bind_name || bind_index]
      run
    end

    def respond_to_missing? meth, *args
      puts "respond to missing from match proxy group"
    end
    
    def method_missing meth, *args
      $stdout.puts "distributing method call #{meth} to match_obj group"
      v = @comp_obj.map do |c|
        c.__send__ meth, *args
      end
      MatchProxyGroup.new(*v)
    end
  end
end
#  vim: set ts=2 sw=2 tw=0 :
