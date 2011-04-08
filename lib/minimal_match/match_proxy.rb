module MinimalMatch
  
  class AbstractMatchProxy < MinimalMatchObject
    attr_accessor :comp_obj
    include MatchMultiplying
    include Alternate
    undef_method :to_s, :respond_to?, :is_a?, :class

    def initialize klass = nil
      super(klass)
      @is_proxy = true #always!
    end

    def to_s
      @comp_obj.to_s
    end

    def === val
      # enables classification if we are proxying a class object
      # doesn't work the other direction.  TFS
      @comp_obj.__send__ :===, val
    end

    private :initialize
  end
    
  
  class MatchProxy < AbstractMatchProxy 

    def initialize val
      super(val.class)
      # pass an array into match proxy to create a
      # group
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
    
    def inspect
      "<#{@comp_obj.to_s} : MatchProxy>"
    end

    def coerce arg
      return self, MatchProxy.new(arg)
    end

    def method_missing meth, *args
      puts "sent #{meth} with #{args}"
      @comp_obj.__send__ meth, *args
    end
  end

  class MatchProxyGroup < AbstractMatchProxy 

    def initialize *vals
      super(MatchProxyGroup)
      @comp_obj = vals.collect do |v| 
        if is_proxy? v or is_match_op? v then v else MatchProxy.new(v) end 
      end
      self
    end
    
    def inspect
      str = ""
      @comp_obj.each do |i|
        str << i.inspect
      end
    end
    
    def is_group?
      true
    end

    def to_s
      str = "m("
      str << @comp_obj.collect do |i|
        i.to_s
      end.join(',')
      str << ")"
    end

    # not sure if that's the best way to do this or not
    def each *args, &block
      @comp_obj.each *args, &block
    end

    def each_with_index *args, &block
      @comp_obj.each_with_index *args, &block
    end

    def coerce arg
      # i don't know if this is what I want to do or not
      $stdout.put "coerce #{arg} for matchproxy group"
      @comp_obj.each_with_object [] do |memo, v|
        memo << v.coerce(arg)
      end
    end

    def method_missing meth, *args
      $stdout.puts "distributing method call #{meth} to match_obj group"
      @comp_obj.map do |c|
        c.__send__ meth, *args
      end
    end
  end
end
#  vim: set ts=2 sw=2 tw=0 :
