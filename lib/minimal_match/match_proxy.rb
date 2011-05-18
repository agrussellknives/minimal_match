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
      s = "m(#{@comp_obj.to_s})"
    end

    def bind name = nil
      pg = MatchProxyGroup.new(@comp_obj)
      if name
        pg.bind(name)
      end
      pg
    end
    alias :capture :bind
    
    def inspect
      "<#{@comp_obj.inspect} : MatchProxy>"
    end

    def method_missing meth, *args
      res = @comp_obj.__send__ meth, *args
      if [true, false, nil].include? res or is_proxy? res 
        res 
      else 
        MatchProxy.new(res) 
      end # return a new proxy object unless it's t,f,n 
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
        if is_proxy? i and not is_group? i
          i.comp_obj.to_s
        elsif is_match_op? i
          i.to_s
        elsif i.comp_obj.is_a? ::Symbol #yeahhh
          ":#{i.comp_obj.to_s}"
        end
      end.join(',')
      str << ")"
      str << ".bind" if @comp_obj.length == 1
      str
    end

    # not sure if that's the best way to do this or not
    def to_ary
      @comp_obj
    end

    def _compile bind_index = nil
      run = [[:hold, @bind_name || bind_index ]] # replace this with bind_index
      @comp_obj.each_with_index.each_with_object(run) do |(mi, idx), memo|
        memo << mi.compile(bind_index+idx+1)
      end
      run << [:save, @bind_name || bind_index]
      run
    end

    def respond_to_missing? meth, *args
      puts "respond to missing from match proxy group"
    end
   
    # i don't know if this is really the correct way to do this or not....
    def method_missing meth, *args
      res = @comp_obj.__send__ meth, *args
      if is_proxy? res and is_group? res then
        res
      elsif res.is_a? ::Enumerable
        MatchProxyGroup.new(*res) # return a new proxy group 
      else
        res
      end
    end
  end
end
#  vim: set ts=2 sw=2 tw=0 :
