#necessary sub files
%w{ match_multiplying anything any_of match_proxy 
    array_match_data reversible_enumerator}.each { |mod| require "#{File.dirname(__FILE__)}/#{mod}"}

require 'fiber'

module Kernel
  def m(val)
    MinimalMatch::MatchProxy.new(val)
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

  def noop; NoOp.instance(); end
    
  def maybe(val); MatchProxy.new(val).maybe; end
  module_function :maybe

  def ends_with(val); End.new(val); end
  module_function :ends_with

  def begins_with(val); Begin.new(val); end
  module_function :begins_with

  def match_proc(&block); MatchProc.new &block; end
  module_function :match_proc

  def compile match_array
    is = [] 
    match_array.each_with_index do |mi, idx|
      i = is.length
      case mi
        when OneOrMore  # +
          is << [:char, mi.comp_obj]
          is << (mi.greedy? ? [:split, i, i+2] : [:split, i+2, i])
          is << [:noop]
        when ZeroOrOne  # ?
          is << (mi.greedy? ? [:split, i+1, i+2] : [:split,i+2,i+1])
          is << [:char, mi.comp_obj]
          is << [:noop]
        when ZeroOrMore # *
          is << (mi.greedy? ? [:split, i+1, i+3] : [:split,i+3,i+1])
          is << [:char, mi.comp_obj]
          is << [:jump, i]
          is << [:noop]
        when NoOp
          is << [:noop]
        when AnyOf
          is << [:any, mi]
        when Alternation # alt
          is << [:split, i+1, i+3]
          is << [:char, mi.comp_obj]
          is << [:jump, i+4]
          is << [:char, mi.alt_obj]
        #simple litterals 
        when MatchProxy, MinimalMatchObject # char
          is << [:char, mi.comp_obj]
        else
          is << [:char, mi]
      end
    end
    is << [:match]
    is
  end
  module_function :compile


        

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

  def =~ match_array_orig
    @debug = true
    match_self = self.dup #dup self to the local so that we don't mess it up
    match_array = match_array_orig.dup
  
   
    puts "comping #{match_self} to #{match_array}"

    included_length = false

    #there is no need to look past END or before BEGINh
    # ignore thie optimzation for now
    has_end, has_begin = false
    match_array.find_all { |i| i.kind_of? MarkerObject }.each do |val| 
      case val
        when End
          match_array = match_array[0..match_array.index(val).prev]
          has_end = true
        when Begin
          match_array = match_array[match_array.index(val).succ..-1]
          has_begin = true
        when Maybe
          # substract one of the necessary length for a match
          # for each maybe
          included_length ||= match_array.length
          included_length -= 1
      end
    end
    
    unless has_begin
      match_array.unshift anything.to_a.non_greedy
    end

    unless has_end
      match_array.push anything.to_a
    end

    #if match_self.length < (included_length || match_array.length)
       #return false
    #end

    ma = compile match_array
    
    match_enum = ReversibleEnumerator.new ma
    self_enum = ReversibleEnumerator.new match_self 


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
    p ma
    stop_flag = false
    first_idx = nil
    last_idx = nil

    cmp_lamb = lambda do |match_enum,self_enum|
      p match_enum.current
      loop do 
        case match_enum.current[0] 
         when :char # this is the only code that actually does a comparison
           break false unless cond_comp[match_enum.current[1], self_enum.current]
           puts "match at #{self_enum.index}" 
           first_idx ||= self_enum.index
           match_enum.next and self_enum.next #advance both
         when :noop
           puts "advance match"
           match_enum.next #advance enumerator, but not match
           next
         when :match
           last_idx = self_enum.index
           break true
         when :jump
           puts "jump match"
           match_enum[match_enum.current[1]] # set the index
           next 
         when :split
           # branch1
           puts "splitting"
           b1 = match_enum.dup # create a new iterator to explore the other branch
           b1.index = match_enum.current[1]
           if cmp_lamb[b1,self_enum]
             break true
           else
             match_enum.index = match_enum.current[2]
             next
           end
        end
      end
    end

    match_enum.next and self_enum.next #start

    mt_found = !!(cmp_lamb.call match_enum, self_enum)
    p match_enum.current
    
    debugger
    1

    true if match_enum.current[0] == :match
    #@first_index = first_idx
    #@last_index = last_idx
    #mt_found

  end
end
