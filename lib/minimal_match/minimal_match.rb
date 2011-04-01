#necessary sub files
%w{ match_multiplying anything any_of array_match_data reversible_enumerator}.each { |mod| require "#{File.dirname(__FILE__)}/#{mod}"}

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

  def compile match_array
    is = [] 
    match_array.each do |mi|
      i = is.length
      case mi
        when OneOrMore  # +
          is << [:char, mi.comp_obj]
          is << [:split, i, i+2]
          is << [:noop]
        when ZeroOrOne  # ?
          is << [:split, i+1, i+2]
          is << [:char, mi.comp_obj]
          is << [:noop]
        when ZeroOrMore # *
          is << [:split, i+1, i+2]
          is << [:char, mi.comp_obj]
          is << [:jump, i]
          is << [:noop]
        when AnyOf      # alt
          is << [:split, i+1, i+3]
          is << [:char, compile(mi.shift)]
          is << [:jump, i+4]
          is << [compile(mi.comp_obj)]
        #simple litterals 
        when MatchProxy, MinimalMatchObject # char
          is << [:char, mi.comp_obj]
        else
          is << [:char, mi]
      end
    end
    is
  end


        

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

  def =~ match_array
    @debug = true
    match_self = self.dup #dup self to the local so that we don't mess it up
   
    puts "comping #{match_self} to #{match_array}"

    included_length = false

    #there is no need to look past END or before BEGINh
    # ignore thie optimzation for now
    has_end, has_begin = false
    match_array.find_all { |i| i.kind_of? MarkerObject }.each do |val| 
      case val
        when End
          match_array = match_array[0..match_array.index(val).prev]
        when Begin
          match_array = match_array[match_array.index(val).succ..-1]
        when Maybe
          # substract one of the necessary length for a match
          # for each maybe
          included_length ||= match_array.length
          included_length -= 1
      end
    end
    
    unless has_begin
      match_array.unshift anything.to_a
    end

    unless has_end
      match_array.push anything.to_a
    end

    #if match_self.length < (included_length || match_array.length)
       #return false
    #end
    debugger

    ma = compile match_array
    
    match_enum = ReversibleEnumerator.new ma
    self_enum = ReversibleEnumerator.new match_self 

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
    cmp_lamb = lambda do |val,match|
       case val[0]
        when :char
          false unless cond_comp val[1], match
          cmp_lamb.call match_enum.next, self_enum.next
        when :noop
          true
        when :jump
          cmp_lamb.call((match_enum.index=val[1]), self_enum.current)
        when :split
          if cmp_lamb.call((match_enum.index=val[1]),self_enum.current)
            true
          else
            cmp_lamb.call((match_enum.index=val[2]),self_enum.current)
          end
       end
       #falls off the end
    end

    mt_found = !!(cmp_lamb.call match_enum.next, self_enum.next)
    @first_index = first_idx
    @last_index = last_idx
    mt_found

  end
end
