require 'singleton'

module MinimalMatch
  class ZeroOrMore 
    attr_accessor :comp_obj
    def === other
      self.comp_obj === other
    end
    alias :== :===
  end

  class OneOrMore < ZeroOrMore; end
  class ZeroOrOne < ZeroOrMore; end

  module MatchMultiplying
    attr_accessor :non_greedy

    module MatchArray
      attr_accessor :type
      def match_array
        true
      end
    end

    def MatchMultiplying.flatten_match_array ma
      ma.inject([]) do |m,o|
        # check if it's a match anything array. since it's fairly
        # likely the other object just doesn't respond to thatmessage
        # assume it isn't if it doesn't
        if (o.match_array rescue false) 
          m.concat o
        else
          m << o 
        end
      end
    end 
    
    def * num
      raise ArgumentError, "can't multiply by non Fixnum #{num}" unless num.is_a? Fixnum
      k = []
      num.times do
        k << self
      end
      k.extend MatchArray #make it respond to "match_array"
      return k 
    end

    def [] range
      #this is where 2..8 would go
      raise NotImplemented
    end

    def +@
      @one_or_more_obj ||= count_class(OneOrMore)
    end

    def maybe
      @one_or_zero_obj ||= count_class(ZeroOrOne) 
    end

    def to_a
      @zero_or_more_obj ||= count_class(ZeroOrMore)
    end

    private
    def count_class super_class
      t = self.instance_eval <<-RUBY 
        Class.new(#{super_class}) do
        include Singleton
        attr_accessor :comp_obj
        def to_s
          "#{super_class}Matching #{self.comp_obj.to_s}>"
        end
      end
      RUBY
      t.instance.comp_obj = self
      t.instance
    end
  end
end
#  vim: set ts=2 sw=2 tw=0 :
