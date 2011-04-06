module MinimalMatch
  
  class AbstractMatchProxy < MinimalMatchObject
    attr_accessor :comp_obj
    include MatchMultiplying
    include Alternate

    def initialize
      super()
    end

    def is_proxy?
      true
    end

    private :initialize
  end
    
  
  class MatchProxy < AbstractMatchProxy 

    def initialize val
      super()
      # pass an array into match proxy to create a
      # group
      @comp_obj = val
      @ancestry.unshift @comp_obj.class
      self
    end
    undef_method :to_s, :respond_to?, :is_a?  # you want the proxy to get these

    def real_class
      @comp_obj.class
    end

    def is_group?
      false
    end
    
    def is_proxy?
      true
    end

    def inspect
      "<#{@comp_obj.to_s} : MatchProxy>"
    end

    def coerce arg
      $stdout.puts "coerce #{arg} to match Proxy"
      return self, MatchProxy.new(arg)
    end

    def method_missing meth, *args
      @comp_obj.__send__ meth, *args
    end
  end

  class MatchProxyGroup < AbstractMatchProxy 

    def initialize *vals
      super()
      @comp_obj = vals.map { |v| MatchProxy.new(v) }
      self
    end
    
    def inspect
      str = ""
      @comp_obj.each do |i|
        str << i.to_s
      end
    end

    def real_class
      @comp_obj.map(&:real_class) 
    end

    def is_group
      true
    end

    def coerce arg
      # i don't know if this is what I want to do or not
      $stdout.put "coerce #{arg} for matchproxy group"
      @comp_obj.each_with_object [] do |memo, v|
        memo << [self, v]
      end
    end

    def method_missing meth, *args
      $stdout.puts "distributing method call to match_obj group"
      @comp_obj.map do |c|
        c.__send__ meth, *args
      end
    end
  end
end
#  vim: set ts=2 sw=2 tw=0 :
