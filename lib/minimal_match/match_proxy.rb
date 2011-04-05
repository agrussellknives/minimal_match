module MinimalMatch
  class MatchProxy < BasicObject 
    #instance_methods.each { |m| undef_method m unless m =~ /^__|include/ }
    
    attr_accessor :comp_obj
    include MatchMultiplying
    include Alternate
    
    def initialize val
      @comp_obj = val
      self
    end
    
    def index_tracker?
      !!(@index_tracker)
    end

    def index_tracker arg
      @index_tracker ||= arg
    end

    def is_proxy?
      true
    end

    def to_s
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
end

#  vim: set ts=2 sw=2 tw=0 :
