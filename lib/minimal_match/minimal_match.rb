#necessary sub files
%w{ match_multiplying anything any_of array_match_data }.each { |mod| require "#{File.dirname(__FILE__)}/#{mod}"}

class Enumerator
  def end?
    !(!!self.peek) rescue true
  end
end

module MinimalMatch

  class MatchProc < Proc
    include MatchMultiplying
  end

  class MarkerObject < MinimalMatchObject
    def initialize val
      super()  #huh
      @comp_value = val
    end

    def === val
      @comp_value === val
    end

    def inspect
      "<#{self.class} == #{comp_value}>"
    end
    alias :== :===
  end

  class End < MarkerObject; end
  class Begin < MarkerObject; end 

  def ends_with(val); End.new(val); end
  module_function :ends_with

  def begins_with(val); Begin.new(val); end
  module_function :begins_with

  def match_proc; MatchProc.new &block; end
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
  
  def MinimalMatch.flatten_match_array ma
    MinimalMatch::MatchMultiplying.flatten_match_array ma
  end

  # non-recursively find the index of a pattern matching `pattern`
  #
  def match match_array
    if self =~ match_array
      ArrayMatchData.new(self, match_array, @first_index, @end_index)
    else
      nil
    end
  end

  def =~ match_array
    match_array = MinimalMatch.flatten_match_array match_array #flatten specific length matches
    match_self = self.dup #dup self to the local so that we don't mess it up
    
    ind = false 

    #there is no need to look past END or before BEGIN
    match_array.find_all { |i| i.kind_of? MarkerObject }.each do |val| 
      case val
        when End
          match_array = match_array[0..match_array.index(val)]
        when Begin
          match_array = match_array[match_array.index(val)..-1]
      end
    end

    if match_self.length < (ind || match_array.length)
       return false
    end
    
    match_enum = match_array.each
    self_enum = match_self.each_with_index
    
    first_idx = nil
    last_idx = nil

    cond_comp = lambda do |self_val, comp_val|
      op_sym = (self_val.is_a? Array and comp_val.is_a? Array) ? :=~ : :===
      p "will compare #{self_val} to #{comp_val} using #{op_sym}"
      if op_sym == :===
        r = self_val.__send__ op_sym, comp_val
      else
        r = comp_val.__send__ op_sym, self_val
      end
      puts "(it was #{r})"
      r
    end
    
    # what i need to do is only iterate self_enum until the value
    # matches the item immediately after the splat
    cmp_lamb = lambda do |val|
      prev_idx = last_idx
      begin
        if self_enum.end?
          return false
        end
        match_item, last_idx = self_enum.next
        found = cond_comp[val, match_item]
        if found and val.kind_of? MarkerObject then
          debugger if End === val 
          case val
            when End
              return false if last_idx != (match_self.length - 1)
            when Begin
              return false if last_idx != 0
          end
        end
           
        last = if val.kind_of? AnyNumber then cond_comp[match_enum.peek, self_enum.peek[0]] else false end rescue true
        if found and not prev_idx.nil?
          return false unless prev_idx.succ == last_idx
        end
        puts "found #{found}"
      end until found
      first_idx ||= last_idx
      res = unless match_enum.end? 
        nv = if not val.kind_of? AnyNumber or last then
          puts "nexted match_enum"
          match_enum.next
        else
          puts "left match _enum"
          val
        end
        cmp_lamb.call(nv)
      else
        true
      end
      puts "res = #{res}"
      res
    end

    mt_found = !!(cmp_lamb.call match_enum.next)
    @first_index = first_idx
    @last_index = last_idx
    mt_found
       
    #match_array.zip(match_self[idx..-1]).each_with_index do |comp,index|
      #if comp[0].is_a? Array and comp[1].is_a? Array
        #return false unless comp[1] =~ comp[0]
      #else 
        ## comp 0 is our comparison array, comp[1] is us.
        ## the case quality operator is not commutative
        ## so it's got to be in this order
        #unless comp[0] === comp[1]
          #return false
        #end 
      #end
    #end
    #true
  end
end
