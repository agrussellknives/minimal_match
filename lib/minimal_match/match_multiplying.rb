require 'singleton'

module MinimalMatch

  # abstrac repetition class
  class Repetition < MinimalMatchObject 

    def initialize comp_obj, &block
      # you define a new to_s method for each
      # subclass whenever you instantiate it
      instance_eval(&block) if block_given?
      raise 'oh shit. shitshitshitshit' unless comp_obj.is_proxy?
      @comp_obj = comp_obj
    end
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

  class ZeroOrMore < Repetition
    def to_s
      "*(m(#{@comp_obj}))"
    end
  end
  class OneOrMore < Repetition
    def to_s 
      "+(m(#{@comp_obj}))"
    end
  end
  class ZeroOrOne < Repetition
    def to_s
      "~(m(#{@comp_obj}))"
    end
  end
  class CountedRepetition < Repetition
    attr_reader :range
    def initialize range, comp_obj, &block
      super(comp_obj, &block)
      @range = range

      str_rep = comp_obj.inspect
      self.define_singleton_method :inspect do
        "CountedReptitionFor #{str_rep}"
      end
      self
    end
    def to_s
      "m(#{@comp_obj.to_s})[#{@range.begin}..#{@range.end}]"
    end
  end

  class NoOp < MinimalMatchObject; end
  NoOp.__send__ :include, Singleton

  class Alternation < MinimalMatchObject
    attr_accessor :alt_obj, :comp_obj
    def initialize comp_obj, arg
      super()
      @alt_obj = arg
      @comp_obj = comp_obj
    end
    def inspect
      "<#{@comp_obj.inspect} or #{@alt_obj.inspect}"
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

    def * num
      self[num..num]
    end

    def [] range
      #this is where 2..8 would go
      @rep_obj = CountedRepetition.new range, self do
        def inspect
          "#{@range.begin} to #{@range.end} of #{@comp_obj}"
        end
      end
    end


    def +@
      @one_or_more_obj ||= count_class(OneOrMore)
    end

    def ~@
      @one_or_zero_obj ||= count_class(ZeroOrOne) 
    end

    def to_a
      @zero_or_more_obj ||= count_class(ZeroOrMore)
      [@zero_or_more_obj] # has to actually return array
    end

    private
    def count_class super_class
      super_class.new(self) do 
        self.define_singleton_method :inspect do
          "<#{super_class} Matching #{self.comp_obj.inspect} >"
        end
      end
    end
  end
end
#  vim: set ts=2 sw=2 tw=0 :
