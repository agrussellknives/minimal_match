#necessary sub files
%w{ match_multiplying anything any_of array_match_data }.each { |mod| require "#{File.dirname(__FILE__)}/#{mod}"}

require 'fiber'

class Enumerator
  def end?
    !(!!self.peek) rescue true
  end
end

module MinimalMatch

  class MatchGroup < MinimalMatchObject
    def inspect
      r = @right
      string = "<#{self.class}:##{'%x' % self.__id__ << 1} ->"
      while r
        string << "#{r.to_s}"
        r = r.right
        string << " -> " if r
      end
      string << " >"
      string
    end
  end

  class MatchPattern
    
    
    def initialize ma
      @match_array = ma
    end
    
    def each
      unless block_given?
        ReversibleEnumerator.new @match_array 
      else
        @match_array.each &block
      end
    end

    class ReversibleEnumerator 
      def initialize obj
        @peek_mutex = Mutex.new
        @index = -1 
        @obj = obj
        @enum = Enumerator.new do |y|
          while true
            if @index < @obj.length
              raise StopIteration if @index < 0
              last = @obj[@index]
              y << last
              # you called prev on the first position
              # but you unshifted an item since then
              if @index < 0
                newdex = @obj.index(last)
                raise StopIteration unless newdex
                @index = newdex - 1
              end
            else
              raise StopIteration
            end
          end
        end
      end

      def resume
        @enum.next
      end
      private :resume

      def prev
        @index -= 1
        resume
      end

      def next
        # post add on the first call, preadd on any other call.
        @index += 1 
        resume
      end

      def rewind
        @index = 0
      end

      def peek
        r = nil
        @peek_mutex.synchronize do
          @index += 1
          r = resume
        end
        r
      ensure
        puts "i ran!"
        @index -= 1
        @index = @obj.length - 1 if @index > @obj.length - 1
      end

      def back_peek
        r = nil
        @peek_mutex.synchronize do
          @index -= 1
          r = resume
        end
        r
      ensure 
        puts "i nar!"
        @index += 1
        @index = -1 if @index < -1
      end

      def end?
        !(!!self.peek) rescue true
      end

      def begin?
        !(!!self.back_peek) rescue true
      end
    end
  end
         

  class MatchProxy < MinimalMatchObject
    instance_methods.each { |m| undef_method m unless m =~ /^__|include/ } 
    attr_accessor :comp_obj

    def initialize val
      @comp_obj = val
    end

    def is_proxy
      true
    end

    def to_s
      "<#{@comp_obj.to_s} : MatchProxy>"
    end

    def method_missing meth, *args
      @comp_obj.__send__ meth, *args
    end
  end
  MatchProxy.__send__ :include, MatchMultiplying
  MatchProxy.__send__ :include, LinkObjects

  class MarkerObject < MinimalMatchObject
    def initialize val
      super()  #huh
      @comp_value = val
    end

    def === val
      @comp_value === val
    end
    alias :== :===

    def inspect
      "<#{self.class} == #{@comp_value}>"
    end
    alias :to_s :inspect
  end

  class End < MarkerObject; end
  class Begin < MarkerObject; end 
    
  def maybe(val); MatchProxy.new(val).maybe; end
  module_function :maybe

  def ends_with(val); End.new(val); end
  module_function :ends_with

  def begins_with(val); Begin.new(val); end
  module_function :begins_with

  def match_proc(&block); MatchProc.new &block; end
  module_function :match_proc

  # a very simple array pattern match for minimal s-exp pjarsing
  # basically, if your array contains at least yourmatch pattern
  # then it will match
  # [a] will match
  # [a b c]
  #
  # [a d] will not
  #
  # that's it.
  #
  #
  #
  
  # non-recursively find the index of a pattern matching `pattern`
  #
  def match match_array
    if self =~ match_array
      ArrayMatchData.new(self, match_array, @first_index, @last_index)
    else
      false
    end
  end

  def =~ match_array
    @debug = true
    match_self = self.dup #dup self to the local so that we don't mess it up
   
    puts "comping #{match_self} to #{match_array}"

    included_length = false

    #there is no need to look past END or before BEGINh
    # ignore thie optimzation for now
    #match_array.find_all { |i| i.kind_of? MarkerObject }.each do |val| 
      #case val
        #when End
          #match_array = match_array[0..match_array.index(val)]
        #when Begin
          #match_array = match_array[match_array.index(val)..-1]
        #when Maybe
          ## substract one of the necessary length for a match
          ## for each maybe
          #included_length ||= match_array.length
          #included_length -= 1
        #end
    #end

    #if match_self.length < (included_length || match_array.length)
       #return false
    #end
    
    match_enum = MatchPattern.new(match_array).each
    self_enum = match_self.each_with_index

    first_idx = nil
    last_idx = nil

    cond_comp = lambda do |self_val, comp_val|
      op_sym = (self_val.is_a? Array and comp_val.is_a? Array) ? :=~ : :===
      p "will compare #{self_val} to #{comp_val} using #{op_sym}" if @debug
      if op_sym == :===
        r = self_val.__send__ op_sym, comp_val
      else
        r = comp_val.__send__ op_sym, self_val
      end
      puts "(it was #{r})" if @debug
      r
    end
    
    # what i need to do is only iterate self_enum until the value
    # matches the item immediately after the splat
    stop_flag = false
    cmp_lamb = lambda do |val|
      puts val
      begin
        begin
          #debugger if val.kind_of? MarkerObject
          match_item, last_idx = self_enum.next
          case match_item
            when MatchProxy
              found = cond_comp[match_item,val]
            else
              found = cond_comp[match_item,val]
          end
        end until found
        match_enum.end? ? true : cmp_lamb.call(match_enum.next)
      rescue StopIteration
        false
      end
    end

    mt_found = !!(cmp_lamb.call match_enum.next)
    @first_index = first_idx
    @last_index = last_idx
    mt_found

  end
end
