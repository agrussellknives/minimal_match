require 'singleton'

module MinimalMatch

  # abstract repetition class
  class Repetition < MinimalMatchObject 
    def initialize under_prox
      raise ::ArgumentError, "repetition support on matchproxy objects only" unless is_proxy? under_prox 
      super(self.class)
      @comp_obj = under_prox 
      @is_match_op = true
    end
    private :initialize

    def greedy_class
      self.class.greedy_class
    end

    def non_greedy_class
      self.class.non_greedy_class
    end

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
  end

  # create the reptition operators
  # this is one time when i wish ruby had macros,
  # because this is actually pretty fucking confusing.
  # I guess I could take up four times as much
  # code by writing this all explicitly - but it seems
  # nearly as wrong as doing it this way
  # seems like candidate for refactor
  ops = {
  ZeroOrMore: {
    :op_symbol => '*',
    :compile_proc => lambda { |i,block|
      run = []
      tl = @comp_obj.compile(i)
      #tl = [tl] unless is_group? tl or is_match_op? tl
      run << block.call(i+1,i+tl.length+2)
      run.concat tl 
      run << [:jump, i] # back to the split 
      run << [:noop]
  }},
  OneOrMore: {
    :op_symbol => '+',
    :compile_proc => lambda { |i,block|
      run = []
      tl = @comp_obj.compile(i)
      #tl = [tl] unless is_group? tl or is_match_op? tl
      run.concat tl
      run << block.call(i,i+tl.length+1)
      run << [:noop]
  }},
  ZeroOrOne: {
    :op_symbol => '~',
    :compile_proc => lambda { |i,block|
      run = []
      tl = @comp_obj.compile(i)
      #tl = [tl] unless is_group? tl or is_match_op? tl
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

    def non_greedy
      non_greedy_class.new(@range, @comp_obj)
    end
    alias :! :non_greedy
      
    def initialize range, comp_obj, &block
      super(comp_obj, &block)
      @range = range
      self
    end

    def compile_proc
      @comp_obj.__send__ :count_class, ZeroOrOne
    end

    def _compile idx = nil, &block
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
        subexpression << compile_proc
      end

      subexpression.each_with_object [] do |mi,memo|
        i = memo.length + idx
        # this is sort of recursive, but it
        # normalizes the bytecode this way
        memo.concat(MatchCompile.compile(i,mi))
      end
    end

    def to_s
      "#{@comp_obj.to_s}[#{@range.begin}..#{@range.end}]"
    end
    
    def inspect 
      "#{super} #{@range.inspect} of #{@comp_obj.inspect}"
    end
  end

  class CountedRepetitionNonGreedy < CountedRepetition
    class << self
      def greedy_class
        CountedRepetition
      end
    end

    def compile_proc
      @comp_obj.__send__ :count_class, ZeroOrOneNonGreedy
    end
    private :compile_proc

    def greedy
      greedy_class.new(@range,@comp_obj)
    end

    def greedy?
      false
    end

    def to_s
      "#{super}.non_greedy"
    end
  end

  class NoOp < MinimalMatchObject
    include ::Singleton 
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

  class Alternation < MinimalMatchObject
    include Alternate #so you can stack them
    attr_accessor :alt_obj, :comp_obj
    
    def initialize comp_obj, arg
      super()
      @alt_obj = arg
      @comp_obj = comp_obj
      @is_group = true
    end

    # because it takes up more than single instruction
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
      #brch_1 = [brch_1] unless is_group? @comp_obj

      br_2idx = brch_1.length + 2
      brch_2 = @alt_obj.compile(br_2idx) 
      #brch_2 = [brch_2] unless is_group? @comp_obj

      run << [:split, idx + 1, idx+brch_1.length+2] #plus jump and split instructions
      run << brch_1
      run << [:jump, idx + brch_1.length + 1 + brch_2.length + 1] #end of the alternation
      run << brch_2
      run << [:noop]
      run
    end
  end

  module MatchMultiplying

    def [] range
      # coerce non ranges into single length range
      # this method does double duty as an index accessor for matchproxy groups
      if range.is_a? Integer and is_group? self then
        @comp_obj[range]
      else
        cl = @non_greedy ? CountedRepetition.non_greedy_class : CountedRepetition
        cl.new range, self
      end
    end

    def times arg
      if arg.is_a? Range then
        self[arg]
      elsif arg.is_a? Fixnum then
        self[arg..arg]
      else
        raise ArgumentError, "Expected Range or Fixnum, but got #{arg.class}"
      end
    end
    alias :* :times
    
    # If called on a proxy which is is proxying a standard object,
    # this sets the future "greediness" of operators on this object.
    # If called on a proxy which is proxying an operator, it returns
    # a new object with the specified greediness.
    # This is non-recursive, so if called on a MatchProxyGroup which is
    # proxying multiple operators, it will basically have no effect
    # You can call that a bug if you like
    def non_greedy
      @non_greedy = true
      self
    end

    def greedy
      @non_greedy = false
      self
    end

    def greedy?
      !(@non_greedy)
    end

    def !
      debugger
      if greedy?
        self.non_greedy
      else
        self.greedy
      end
    end

    def +@
      @one_or_more_obj ||= count_class(OneOrMore)
      @one_or_more_obj_non_greedy ||= count_class(OneOrMoreNonGreedy)
      @non_greedy ? @one_or_more_obj_non_greedy : @one_or_more_obj
    end
    alias :plus :+@

    def ~@
      @one_or_zero_obj ||= count_class(ZeroOrOne)
      @one_or_zero_obj_non_greedy ||= count_class(ZeroOrOneNonGreedy) 
      @non_greedy ? @one_or_zero_obj_non_greedy : @one_or_zero_obj
    end
    alias :quest :~@

    def to_a
      @zero_or_more_obj ||= count_class(ZeroOrMore)
      @zero_or_more_obj_non_greedy ||= count_class(ZeroOrMoreNonGreedy)
      [@non_greedy ? @zero_or_more_obj_non_greedy : @zero_or_more_obj] # has to actually return array
    end

    # This is the non array version of the KleeneStar operator (in to_a) 
    # this enables you write some pretty pathological expressions which aren't
    # currently caught, so use with care
    def kleene 
      to_a[0]
    end

    private
      def count_class super_class
        super_class.new(self)
      end
  end


# include these modules in the abstract matchproxy
  class AbstractMatchProxy < MinimalMatchObject
    include ::MinimalMatch::MatchMultiplying
    include ::MinimalMatch::Alternate
  end
end

# mix these modules into the match proxy

#  vim: set ts=2 sw=2 tw=0 :
