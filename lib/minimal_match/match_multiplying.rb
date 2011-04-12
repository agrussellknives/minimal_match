require 'singleton'

module MinimalMatch

  # abstrac repetition class
  class Repetition < MinimalMatchObject 

    def initialize comp_obj, &block
      # you define a new to_s method for each
      # subclass whenever you instantiate it
      super()
      instance_eval(&block) if block_given?
      raise ::ArgumentError, "repetition support on matchproxy objects only" unless is_proxy? comp_obj
      @comp_obj = comp_obj
      @is_match_op = true
    end
    private :initialize

    attr_accessor :comp_obj
    def greedy?
      true
    end
    
    def non_greedy
      non_greedy_class.new(@comp_obj)
    end
    alias :-@ :non_greedy

  end

  # create the reptition operators
  ops = { ZeroOrMore: '*',
          OneOrMore: '+',
          ZeroOrOne: '~' }
    
  ops.each_pair do |class_name, op_symbol|
    greedy = Class.new(Repetition) do
      define_method :to_s do
        "#{op_symbol}(#{@comp_obj.to_s})"
      end
      define_method :non_greedy_class do
        ::MinimalMatch.const_get class_name.to_s + "NonGreedy"
      end
      define_method :inspect do
        "#{self.class} of #{self.comp_obj.inspect}"
      end
    end
    non_greedy = Class.new(greedy) do
      define_method :greedy? do
        false
      end
      define_method :to_s do
        "#{op_symbol}(m(#{@comp_obj})).non_greedy"
      end
    end
    self.const_set class_name, greedy
    self.const_set class_name.to_s + "NonGreedy", non_greedy
  end
      
  
  # not generated because the syntax is a little
  # different and it take an additional argument
  # i suppose you could make all of the count
  # operators subclasses of counted repetition 
  # if you were feeling ambitious
  class CountedRepetition < Repetition
    attr_reader :range
    class << self
      def non_greedy_class
        CountedRepetitionNonGreedy
      end
    end
      
    def initialize range, comp_obj, &block
      super(comp_obj, &block)
      @range = range
      self
    end

    def to_s
      "m(#{@comp_obj.to_s})[#{@range.begin}..#{@range.end}]"
    end
    
    def inspect 
      "#{super} #{@range.inspect} of #{@comp_obj.inspect}"
    end
  end

  class CountedRepetitionNonGreedy < CountedRepetition
    def greedy?
      false
    end
    
    def to_s
      "-(#{super})"
    end
  end

  class NoOp < MinimalMatchObject; end
  NoOp.__send__ :include, Singleton

  class Alternation < MinimalMatchObject
    attr_accessor :alt_obj, :comp_obj
    def initialize comp_obj, arg
      super()
      @is_match_op = true
      @alt_obj = arg
      @comp_obj = comp_obj
    end
    def inspect
      "<#{@comp_obj.inspect} or #{@alt_obj.inspect}"
    end

    def to_s
      "m(#{@comp_obj.to_s}) | m(#{@alt_obj.to_s})"
    end
  end

  module Alternate
    def | arg
      unless is_proxy? arg
        self_equiv, arg_equiv = self.coerce(arg) 
      else
        self_equiv, arg_equiv = self, arg
      end

      Alternation.new(self_equiv, arg_equiv)
    end
  end

  module MatchMultiplying

    def * num
      self[num..num]
    end

    def [] range
      # coerce non ranges into single length range
      unless range.is_a? Range then
        r = range.to_i
        raise TypeError, "could not convert #{range} into Range" unless r > 0
        range = [r..r]
      end
      #this is where 2..8 would go
      cl = @non_greedy ? CountedRepetition.non_greedy_class : CountedRepetition
      @rep_obj = cl.new range, self
    end

    # make the non-greedy modifier
    # less particular about parentheses
    def non_greedy
      @non_greedy = true
      self
    end
    alias :-@ :non_greedy

    def greedy
      @non_greedy = false
      self
    end

    def +@
      @one_or_more_obj ||= count_class(OneOrMore)
      @one_or_more_obj_non_greedy ||= count_class(OneOrMoreNonGreedy)
      @non_greedy ? @one_or_more_obj_non_greedy : @one_or_more_obj
    end

    def ~@
      @one_or_zero_obj ||= count_class(ZeroOrOne)
      @one_or_zero_obj_non_greedy ||= count_class(ZeroOrOneNonGreedy) 
      @non_greedy ? @one_or_zero_obj_non_greedy : @one_or_zero_obj
    end

    def to_a
      @zero_or_more_obj ||= count_class(ZeroOrMore)
      @zero_or_more_obj_non_greedy ||= count_class(ZeroOrMoreNonGreedy)
      [@non_greedy ? @zero_or_more_obj_non_greedy : @zero_or_more_obj] # has to actually return array
    end

    private
    def count_class super_class
      super_class.new(self)
    end
  end
end
#  vim: set ts=2 sw=2 tw=0 :
