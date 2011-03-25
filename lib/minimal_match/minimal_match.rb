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

  class End < MinimalMatchObject
    def === must_nil
      must_nil.nil? ? true : false
    end
  end
  class Begin < MinimalMatchObject; end 

  def ending; End.instance(); end
  module_function :ending

  def beginning; Begin.instance(); end
  module_function :beginning

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

    #there is no need to look past END
    if match_array.include?(ending)
      ind = match_array.index(ending)
      match_self = match_self[0..match_array.index(ending)]
      match_array = match_array[0..ind] # you can drop the end marker now
    end

    #or before the beginning
    if match_array.include?(beginning)
      ind = match_array.index(beginning)+1
      match_array = match_array[ind..-1]
    end

       
    if match_self.length < (ind || match_array.length)
       return false
    end
    
    if match_array.detect { |i| i.kind_of? AnyNumber }
      #divide the match array into subarrays, splitting on AnyNumberOfThings
      # [ *anything, 5, *anything, 8] becomes
      # [[5],[8]]
      expanded_match_array = []

      match_array = match_array.inject([[]]) do |res,el|
        if (el.kind_of? AnyNumber)
          (any_num = []).extend MatchMultiplying::MatchArray
          any_num.type = el.comp_obj
          res << any_num 
        else
          res.last << el
        end
        res
      end

      # this first part of the expanded match array is exactly the same.
      # a leading glob will append an empty array
      
      expanded_match_array.concat match_array[0]
       
      # no need to start at the beginning
      idx = expanded_match_array.length
       
      match_array[1..-1].inject(expanded_match_array) do |ema, ma|
        first_occurence = match_self[idx..-1].match(ma).begin
        puts "found #{ma} at #{first_occurence} in #{match_self[idx..-1]}"
        unless first_occurence  #couldn't find a match
          first_occurence = match_self[idx..-1].length #so at the end
        end
        first_occurence.times do
          ema << ma.type 
        end
        ema.concat ma
        idx = ema.length
      end
      
      match_array = expanded_match_array
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

    cmp_lamb = lambda do |val|
      prev_idx = last_idx
      begin
        if self_enum.end?
          puts "returning false"
          return false
        end
        match_item, last_idx = self_enum.next
        found = cond_comp[val, match_item]
        if found and not prev_idx.nil?
          return false unless prev_idx.succ == last_idx
        end
      end until found
      first_idx ||= last_idx
      res = unless match_enum.end? 
        puts "found match at position #{last_idx} advancing..."
        cmp_lamb.call match_enum.next
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
