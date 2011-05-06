#necessary sub files

module

require 'fiber'
require 'singleton'

#
%w{ minimal_match_object match_proxy match_multiplying special_literals
    array_match_data reversible_enumerator}.each { |mod| require "#{File.dirname(__FILE__)}/#{mod}"}

module MinimalMatch

  class MarkerObject < MinimalMatchObject
    # abstract position marker
    include ::Singleton
    def ===
      false
    end

    def to_s
      #memoize the string value after it's calculated
      @s_val ||= lambda { self.class.to_s.gsub("Class",'') }.call
    end

    def inspect
      self.class
    end

    private :initialize
  end

  class EndClass < MarkerObject; end
  class BeginClass < MarkerObject; end

  # you can't access the array "post" from ruby code
  # so you need this to know when you're at the end of
  # the array
  class SentinelClass < MarkerObject; end
 
  Anything = MinimalMatch::AnythingClass.instance
  End = MinimalMatch::EndClass.instance
  Begin = MinimalMatch::BeginClass.instance
  Sentinel = MinimalMatch::SentinelClass.instance

  def noop; NoOp.instance(); end
    
  module ArrayMethods
    def match match_array
      MatchMachine.new(self,pattern).run
    end

    def =~ pattern 
      res = MatchMachine.new(self, pattern).run
      res ? true : false
    end
  end

  class MatchMachine
    include Debugging
    extend MinimalMatch::ProxyOperators
    
    class << self
      def debug_class
        MinimalMatch::DebugMachine
      end
      def compile match_array
        # directly compile raw match group
        if is_proxy? match_array
          return match_array.compile
        end

        is = []
        match_array.each do |mi|
          i = is.length
          if mi.respond_to? :compile
            is.concat(mi.compile(i))
          else
            # so it's just a standard object
            is.concat(MatchCompile.compile(i,mi))
          end
        end
        is << [:match]
      end
    end

    attr_accessor :match_data

    def initialize(subject, pattern) 
      @subject = subject.dup
      @subject << Sentinel
      @pattern = pattern.dup
      @match_data = ArrayMatchData.new(@subject, @pattern)

      has_end, has_begin, has_epsilon = false
      @pattern.find_all { |i| i.kind_of? MarkerObject }.each do |val| 
        case val
          when End
            @pattern = @pattern[0..@pattern.index(val).prev]
            has_end = true
          when Begin
            @pattern = @pattern[@pattern.index(val).succ..-1]
            has_begin = true
          when Repetition 
            # zero width assertions will prevent a simple length check
            # optmization. it's probably possible to figure this
            # out, but we'll skip it for now
            has_epsilon = true
        end
      end

      if not has_epsilon and @subject.length < @pattern.length
         @always_false = true
      end
      
      unless has_begin
        @pattern.unshift(*MatchProxy.new(Anything).non_greedy.to_a)
      end

      unless has_end
        @pattern.concat(MatchProxy.new(Anything).to_a)
      end

      debugger
      
      @program_enum = ReversibleEnumerator.new(MinimalMatch::MatchMachine.compile(@pattern)) 
      @subject_enum = ReversibleEnumerator.new @subject 

      debug(@program_enum, @subject_enum)
      self
    end

    def run
      return false if @always_false

      debug.display_at 0,0
      @pathology_count = 0
      @match_hash = {}
      @program_enum.next and @subject_enum.next
      res = catch :stop_now do
        process @program_enum, @subject_enum
      end
      puts @match_hash
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
           return false unless comp(args, subject_enum.current)
           pattern_enum.next and subject_enum.next #advance both
         when :noop
           pattern_enum.next #advance enumerator, but not match
           next
         when :save
           unless @match_hash.has_key? *args
             @match_hash[args] = {}
             @match_hash[args][:begin] = subject_enum.index
           else
             @match_hash[args][:end] = subject_enum.index
           end
           pattern_enum.next
           next
         # not currently in use
         when :peek
           return false unless comp(args, subject_enum.peek)
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
      thread.close if thread
    end

    def comp(subj_val,pattern_val) 
      op_sym = (subj_val.is_a? Array and pattern_val.is_a? Array) ? :=~ : :===
      if op_sym == :===
        r = subj_val.__send__ op_sym, pattern_val 
      else
        r = pattern_val.__send__ op_sym, subj_val 
      end
      r
    end
  end
end


