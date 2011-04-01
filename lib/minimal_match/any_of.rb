module MinimalMatch
  class AnyOf < BasicObject
    include MatchMultiplying
    class << self
      def [] *args
        self.new(args)
      end
    end

    def initialize(args)
      @match_array << args.each { |i| MatchProxy.new i }
    end

    def method_missing meth, *args
      nil
    end

    def class
      AnyOf
    end
    
    def inspect
      "#{self.class}:#{@match_arr.to_s}"
    end

    def === obj
      @match_arr.each do |m|
        return true if m === obj
      end
      false
    end

    def shift 
      @match_arr.shift
    end
  end

  def any_of
    AnyOf
  end
  module_function :any_of
end
#  vim: set ts=2 sw=2 tw=0 :
