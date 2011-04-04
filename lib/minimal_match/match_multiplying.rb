require 'singleton'

module MinimalMatch
  class ZeroOrMore #abstract
    private :initialize

    attr_accessor :comp_obj
    def greedy?
      true
    end

    def non_greedy_class
      ng = Class.new(self.class) do
        include Singleton
        def greedy?
          false
        end
        def to_s
          "#{(super).chop} non-greedily >"
        end
      end
      ng.instance.comp_obj = self.comp_obj
      ng.instance
    end
    private :non_greedy_class

    def non_greedy
      @ng_version ||= non_greedy_class
    end
  end

  class OneOrMore < ZeroOrMore; end
  class ZeroOrOne < ZeroOrMore; end
  class Repetition < ZeroOrMore; end

  class NoOp < MinimalMatchObject; end
  NoOp.__send__ :include, Singleton

  class Alternation < MinimalMatchObject
    attr_accessor :alt_obj, :comp_obj
    def initialize comp_obj, arg
      super()
      @alt_obj = arg
      @comp_obj = comp_obj
    end
    def to_s
      "<#{@comp_obj.to_s} or #{@alt_obj.to_s}"
    end
    alias :inspect :to_s
  end

  module Alternate
    def | arg
      self_equiv, arg_equiv = self.coerce(arg) 
      Alternation.new(self_equiv.comp_obj, arg_equiv.comp_obj)
    end
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
      self.[num..num]
    end

    def [] range
      #this is where 2..8 would go
      rep_obj = Class.new(self.class) do
        include Singleton
        attr_accessor :range
        def to_s
          "#{range.begin} to #{range.end} of #{@comp_obj}"
        end
      end
      rep_obj.range = range
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
      inc_singleton = self.class <=> Singleton # specialized objects like "Anything"
      ev_obj = (inc_singleton.nil? or inc_singleton < 0) ? self.class : self
      t = ev_obj.instance_eval <<-RUBY 
        Class.new(#{super_class}) do
        include Singleton
        attr_accessor :comp_obj
        def to_s
          "<#{super_class}Matching #{self.comp_obj.to_s} >"
        end
      end
      RUBY
      t.instance.comp_obj = self
      t.instance
    end
  end
end
#  vim: set ts=2 sw=2 tw=0 :
