#necessary sub files
require 'fiber'
require 'singleton'
#
%w{ minimal_match_object match_multiplying match_proxy anything any_of 
    array_match_data reversible_enumerator}.each { |mod| require "#{File.dirname(__FILE__)}/#{mod}"}

module MinimalMatch

  class MarkerObject < MinimalMatchObject
    # abstract position marker
    def ===
      false
    end

    def to_s
      #memoize the string value after it's calculated
      @s_val ||= lambda { self.class.to_s.split('::').last.upcase + '_OBJECT' }.call
    end

    def inspect
      self.class
    end

    private :initialize

  end
  MarkerObject.__send__ :include, Singleton

  class End < MarkerObject; end
  class Begin < MarkerObject; end

  # you can't access the array "post" from ruby code
  # so you need this to know when you're at the end of
  # the array
  class Sentinel < MarkerObject; end 
  
  ANYTHING = MinimalMatch::Anything.instance
  END_OBJECT = MinimalMatch::End.instance
  BEGIN_OBJECT = MinimalMatch::Begin.instance
  SENTINEL_OBJECT = MinimalMatch::Sentinel.instance

  def noop; NoOp.instance(); end
    
  def compile match_array
    is = []
    match_array.each do |mi|
      i = is.length
      run = compile(mi) if mi.kind_of? MatchProxyGroup
      case mi
        when OneOrMore  # +
          is << [:lit, mi.comp_obj]
          is << (mi.greedy? ? [:split, i, i+2] : [:split, i+2, i])
          is << [:noop]
        when ZeroOrOne  # ?
          is << (mi.greedy? ? [:split, i+1, i+2] : [:split,i+2,i+1])
          is << [:lit, mi.comp_obj]
          is << [:noop]
        when ZeroOrMore # *
          is << (mi.greedy? ? [:split, i+1, i+3] : [:split,i+3,i+1])
          is << [:lit, mi.comp_obj]
          is << [:jump, i]
          is << [:noop]
        when CountedRepetition
          # compiles to a number of literals followed by a number
          # of zero or ones.  we could probably do this less
          # explicity using by using redo and rewriting the
          # match array to use ZeroOrMore and MatchProxies,
          # but this is less clever
          if mi.range.begin > 0
            mi.range.begin.times do
              is << [:lit, mi.comp_obj]
            end
          end
          rem = mi.range.end - mi.range.begin
          split_len = rem * 2
          rem.times do |idx|
            is << (mi.greedy? ? [:split, i+idx,i+(rem * 2)] : [:split, i+(rem * 2), i+idx])
            is << [:lit, mi.comp_obj]
          end
          is << [:noop]
        when NoOp
          is << [:noop]
        when AnyOf
          is << [:any, mi]
        when Alternation # alt
          is << [:split, i+1, i+3]
          is << [:lit, mi.comp_obj]
          is << [:jump, i+4]
          is << [:lit, mi.alt_obj]
        #simple litterals 
        when MatchProxy, MinimalMatchObject # char
          is << [:lit, mi.comp_obj]
        else
          is << [:lit, mi]
      end
    end
    is << [:match]
    is
  end
  module_function :compile


  def match match_array
    self =~ match_array
    @last_match || false
  end

  def =~ match_array_orig
    @last_match = false # starts any match operation as false

    @debug = true
    match_self = self.dup #dup self to the local so that we don't mess it up
    match_self << Sentinel.new
    match_array = match_array_orig.dup
  
   
    puts "comping #{match_self} to #{match_array}"

    #there is no need to look past END or before BEGINh
    # ignore thie optimzation for now
    has_end, has_begin, has_epsilon = false
    match_array.find_all { |i| i.kind_of? MarkerObject }.each do |val| 
      case val
        when End
          match_array = match_array[0..match_array.index(val).prev]
          has_end = true
        when Begin
          match_array = match_array[match_array.index(val).succ..-1]
          has_begin = true
        when Repetition 
          # zero width assertions will prevent a simple length check
          # optmization. it's probably possible to figure this
          # out, but we'll skip it for now
          has_epsilon = true
      end
    end

    if not has_epsilon and match_self.length < match_array.length
       return false
    end

    
    unless has_begin
      match_array.unshift anything.to_a.non_greedy
    end

    unless has_end
      match_array.push anything.to_a
    end


    ma = compile match_array
    
    
    # use this function as the comparate to enable
    # recursive matching.
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
    
    p ma
    first_idx = nil
    last_idx = nil
    current_match_data = ArrayMatchData.new

    cmp_lamb = lambda do |match_enum,self_enum|
      p match_enum.current
      loop do 
        case match_enum.current[0] 
         when :lit # this is the only code that actually does a comparison
           break false unless cond_comp[match_enum.current[1], self_enum.current]
           puts "match at #{self_enum.index}" 
           match_enum.next and self_enum.next #advance both
         when :noop
           puts "advance match"
           match_enum.next #advance enumerator, but not match
           next
         when :match
           last_idx = self_enum.index
           puts "match state reached!"
           throw :stop_now #because we don't know how deeply we are nested
         when :jump
           puts "jump match"
           match_enum[match_enum.current[1]] # set the index
           next 
         when :split
           # branch1
           puts "splitting"
           b1 = match_enum.dup # create a new iterator to explore the other branch
           b1.index = match_enum.current[1] #set the index to split location
           if cmp_lamb[b1,self_enum.dup]
             break true
           else
             match_enum.index = match_enum.current[2]
             next
           end
        end
      end
    end
    
    match_enum = ReversibleEnumerator.new ma
    self_enum = ReversibleEnumerator.new match_self 

    match_enum.next and self_enum.next #start
    catch :stop_now do
      cmp_lamb.call match_enum, self_enum
    end
    
    true if match_enum.current[0] == :match
  end
end
