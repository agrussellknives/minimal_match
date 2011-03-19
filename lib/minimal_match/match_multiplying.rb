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
    def MatchMultiplying.flatten_match_array ma
      ma.inject([]) do |m,o|
        if o.instance_variable_get :@match_array
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
      k.instance_variable_set :@match_array, true
      return k 
    end

    def to_a
      unless @number_obj
        ar_class = Class.new(AnyNumber) do
          include Singleton
          def to_s
            name = self.comp_obj.class.to_s.split('::').last
            "#<AnyNumberMatching_#{name} instance: #{self.comp_obj.to_s}>"
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
