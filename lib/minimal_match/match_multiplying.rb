require 'singleton'

module MinimalMatch
  class AnyNumber
    attr_accessor :comp_obj
    def === other
      self.comp_obj === other
    end
    alias :== :===
  end

  module MatchMultiplying
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

    def to_a
      unless @number_obj
        ar_class = Class.new(AnyNumber) do
          include Singleton
          attr_accessor :comp_obj
          def to_s
            name = self.comp_obj.class.to_s.split('::').last
            "#<AnyNumberMatching_#{self.comp_obj.to_s}>"
          end
        end
        @number_obj = ar_class.instance()
        @number_obj.comp_obj = self
      end
      [@number_obj]
    end
  end
end
#  vim: set ts=2 sw=2 tw=0 :
