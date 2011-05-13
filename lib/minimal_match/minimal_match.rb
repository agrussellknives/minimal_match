#necessary sub files

require 'fiber'
require 'singleton'

#
%w{ minimal_match_object match_proxy match_multiplying special_literals
    array_match_data reversible_enumerator}.each { |mod| require "#{File.dirname(__FILE__)}/#{mod}"}

module MinimalMatch

  def last_match
    @last_match || nil
  end
  module_function :last_match

  def noop; NoOp.instance(); end
    
  module ArrayMethods
    def match pattern 
      MatchMachine.new(self,pattern).run
    end

    def =~ pattern 
      res = MatchMachine.new(self, pattern).run
      res ? true : false
    end
  end

  class MatchPattern
    include MinimalMatch::ProxyOperators

    UNANCHORED_BEGIN = MatchProxy.new(Anything).kleene.non_greedy
    UNANCHORED_END = MatchProxy.new(Anything).kleene

    attr_reader :has_end, :has_begin, :has_epsilon
    attr_accessor :pattern 

    #cause I'm lazy
    alias :has_end? :has_end
    alias :has_begin? :has_begin
    alias :has_epsilon? :has_epsilon
    
    def initialize pattern
      if is_group? pattern or is_proxy? pattern or is_match_op? pattern
        pattern = [pattern] # so we don't capture the leading and trailing kleens
      end
      @has_end = @has_begin = @has_epsilon = false
      pattern.find_all { |i| is_match_op? i }.each do |val| 
        case val
          when EndClass
            pattern = pattern[0 .. pattern.index(val)]
            @has_end = true
          when BeginClass
            pattern = pattern[pattern.index(val).succ .. -1]
            @has_begin = true
          when Repetition 
            # epsilon transitions will prevent a simple length check
            # optmization. it's probably possible to figure this
            # out, but we'll skip it for now
            @has_epsilon = true
        end
      end
     
      unless has_begin
        # make sure not to double do it
        pattern.unshift UNANCHORED_BEGIN unless pattern[0].eql? UNANCHORED_BEGIN
      end

      unless has_end
        pattern.push UNANCHORED_END unless pattern[-1].eql? UNANCHORED_END
      end

      @pattern = pattern
    end

    def length
      if @has_epsilon
        return 0.0 / 0.0 #that's crazy
      else
        #counts the number of lliterals not enclosed in reptition operators
        # on this level
        compiled.select do |i,*a|
          if (i == :split) .. (i == :noop) then #it's a flip flop! 
            false
          else
            i == :lit
          end
        end.length
      end
    end

    def to_s
      @pattern.each_with_object("[") do |i,memo|
        unless [UNANCHORED_END, UNANCHORED_BEGIN].include? i then
          memo << i.to_s + ","
        end
      end.chop.concat "]"
    end

    def inspect
      @pattern.reject do |i|
        [UNANCHORED_BEGIN, UNANCHORED_END].include? i
      end.inspect
    end

    def compiled
      return @compiled if @compiled
      compile
      @compiled
    end

    def compile
      is = [[:hold, 0]]
      @pattern.each do |mi|
        i = is.length
        is.concat(MatchCompile.compile(i,mi))
      end
      is << [:save, 0]
      is << [:match]
      @compiled = is
      true
    end
  end

  class MatchMachine
    include Debugging
    
    class << self
      def debug_class
        MinimalMatch::DebugMachine
      end
    end

    attr_accessor :match_data

    def initialize(subject, pattern) 
      subject = subject.dup
      subject << Sentinel
      pattern = pattern.respond_to?(:compiled) ? pattern.dup : MinimalMatch::MatchPattern.new(pattern.dup) 
      @match_data = ArrayMatchData.new(subject, pattern)

      if not pattern.has_epsilon and subject.length < pattern.length
        @always_false = true
      end
      
      @program_enum = ReversibleEnumerator.new pattern.compiled
      @subject_enum = ReversibleEnumerator.new subject 

      debug(@program_enum, @subject_enum)
      self
    end

    def run
      @pathology_count = 0 
      return false if @always_false
      debug.display_at 0,0
      @match_hash = {}
      @program_enum.next and @subject_enum.next
      res = catch :stop_now do
        process @program_enum, @subject_enum
      end
      @match_hash.each do |key,match|
        @match_data.instance_exec(key,match) do |k,m|
          @captures[k] = m
        end
      end
      MinimalMatch.__send__ :instance_variable_set, :@last_match, @match_data
      res ? @match_data : false
    end

    def process pattern_enum, subject_enum, thread = nil
      @pathology_count += 1
      
      loop do
        op, *args = pattern_enum.current
        #smells funny, but i thinkg this is actually correct
        args = (args.length == 1 ? args[0] : args) rescue false
        
        # debugging output
        debug.thread(thread).update_inplace subject_enum.index, pattern_enum.index
        debug.puts_inplace "Pathology = #{@pathology_count} Idx = #{[subject_enum.index, pattern_enum.index]}"

        case op 
         when :lit # this is the only code that actually does a comparison
           return false unless r = comp(subject_enum.current, args)
           @match_data.sub_match[subject_enum.index] = r if r.is_a? ArrayMatchData
           pattern_enum.next and (subject_enum.next unless subject_enum.end?)
         when :noop
           pattern_enum.next #advance enumerator, but not match
           next
         when :hold
           @match_hash[args] = { :begin => subject_enum.index }
           pattern_enum.next
           next
         when :save
           @match_hash[args][:end] = subject_enum.index - 1 #reports always one past end
           pattern_enum.next
           next
         # not currently in use
         when :peek
           return false unless comp(subject_enum.peek, args)
           pattern_enum.next and subject_enum.next #advance both
         when :match
           last_idx = subject_enum.index
           throw :stop_now, true #because we don't know how deeply we are nested
         when :jump
           pattern_enum[args] # set the index
           next 
         when :split
           # branch1
           b1 = pattern_enum.dup # create a new iterator to explore the other branch set the index to split location
           b1.index = args.first
           if process(b1,subject_enum.dup, debug.new_thread)
             return true
           else
             pattern_enum.index = args.last
             next
           end
        end
      end
    ensure
      #debugging
      thread.close if thread
    end

    def comp(subj_val,pattern_val)
      op_sym = (subj_val.is_a? Array and pattern_val.is_a? Array) ? :match : :===
      if op_sym == :===
        r = pattern_val.__send__ op_sym, subj_val  #because === isn't commutative
      else
        r = subj_val.__send__ op_sym, pattern_val
      end
    end
  end
end



