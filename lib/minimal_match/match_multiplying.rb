require 'singleton'
require 'sender'

module MinimalMatch

  # abstract repetition class
  class Repetition < MinimalMatchObject 
    def initialize under_prox, &block
      # you define a new to_s method for each
      # subclass whenever you instantiate it
      raise ::ArgumentError, "repetition support on matchproxy objects only" unless is_proxy? under_prox 
      super()
      @comp_obj = under_prox 
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

    def greedy
      greedy_class.new(@comp_obj)
    end

    def !
      if greedy? then non_greedy else greedy end
    end

    def method_missing meth, *args
      # for some reason __sender__ chokes this
      puts "sent #{__method__} with #{args.to_s} from #{__caller__} from group underproxy"
      @comp_obj.__send__ meth, *args
    end
  end

  # create the reptition operators
  # this is one time when i wish ruby had macros,
  # because this is actually pretty fucking confusing.
  # I guess I could take up four times as much
  # code by writing this all explicitly - but it seems
  # wrong seems like candidate for refactor
  ops = {
  ZeroOrMore: {
    :op_symbol => '*',
    :compile_proc => lambda { |i,block|
      run = []
      tl = @comp_obj.compile(i)
      run << block.call(i+1,i+tl.length+2)
      run.concat tl 
      run << [:jump, i]
      run << [:noop]
  }},
  OneOrMore: {
    :op_symbol => '+',
    :compile_proc => lambda { |i,block|
      run = []
      tl = @comp_obj.compile(i)
      run.concat tl
      run << block.call(i,i+tl.length+1)
      run << [:noop]
  }},
  ZeroOrOne: {
    :op_symbol => '~',
    :compile_proc => lambda { |i,block|
      run = []
      tl = @comp_obj.compile(i)
      run << block.call(i+1,i+tl.length+1)
      run.concat tl
      run << [:noop]
  }}}
     
  ops.each do |class_name, values|
    op_symbol, compile_proc = values.values
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
      define_method :_compile do |i|
        instance_exec i, lambda { |idx,len| [:split,idx,len] }, &compile_proc
      end
    end
    non_greedy = Class.new(greedy) do
      define_method :greedy? do
        false
      end
      define_method :greedy_class do
        greedy
      end
      define_method :to_s do
        "#{super()}.non_greedy"
      end
      define_method :_compile do |i| 
        instance_exec i, lambda { |idx,len| [:split,len,idx] }, &compile_proc
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
   
    # yeah, it can actually be called either way 
    class << self
      def non_greedy_class
        CountedRepetitionNonGreedy
      end
    end

    def non_greedy_class
      CountedRepetitionNonGreedy
    end
    
    def non_greedy
      non_greedy_class.new(@range, @comp_obj)
    end
    alias :-@ :non_greedy
      
    def initialize range, comp_obj, &block
      super(comp_obj, &block)
      @range = range
      self
    end

    def _compile idx = nil
      run = []
      # rewrite the subexpression to a number of literals
      # followed by a number of zero or ones
      subexpression = []

      if @range.begin > 0
        @range.begin.times do
          subexpression << @comp_obj #comp_obj is always a proxy
        end
      end

      remaining = @range.end - @range.begin
      remaining.times do
        subexpression << greedy? ? ~(@comp_obj) : ~!(@comp_obj)
      end
    
      subexpression.compile(idx)
    end

    def to_s
      "#{@comp_obj.to_s}[#{@range.begin}..#{@range.end}]"
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
      "#{super}.non_greedy"
    end
  end

  class NoOp < MinimalMatchObject; end
  NoOp.__send__ :include, Singleton

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

 class Alternation < MinimalMatchObject
    include Alternate #so you can stack them

    attr_accessor :alt_obj, :comp_obj
    def initialize comp_obj, arg
      super()
      @is_match_op = true
      @alt_obj = arg
      @comp_obj = comp_obj
    end

    # because it takes up more than single instruction
    def is_group?
      true
    end

    def inspect
      "<#{@comp_obj.inspect} or #{@alt_obj.inspect}"
    end

    def to_s
      "#{@comp_obj.to_s}|#{@alt_obj.to_s}"
    end

    def _compile idx = nil
      run = []
      br_1idx = idx + 1
      brch_1 = @comp_obj.compile(br_1idx) 
      brch_1 = [brch_1] unless @comp_obj.is_group?
      
      br_2idx = brch_1.length + 2
      brch_2 = @alt_obj.compile(br_2idx) 
      brch_2 = [brch_2] unless @alt_obj.is_group?

      run << [:split, idx + 1, idx+brch_1.length+2] #plus jump and split instructions
      run.concat brch_1
      run << [:jump, idx + brch_1.length + 1 + brch_2.length + 1] #end of the alternation
      run.concat brch_2
      run << [:noop]
      run
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

    #aliasing this doesn't work
    def greedy
      @non_greedy = false
      self
    end

    def greedy?
      !(@non_greedy)
    end

    def !
      if @non_greedy then greedy else non_greedy end
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


  # include these module in the abstract matchproxy
  AbstractMatchProxy.__send__ :include, ::MinimalMatch::MatchMultiplying
  AbstractMatchProxy.__send__ :include, ::MinimalMatch::Alternate
end

# mix these modules into the match proxy

#  vim: set ts=2 sw=2 tw=0 :
