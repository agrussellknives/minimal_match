#necessary sub files
%w{ match_multiplying anything any_of }.each { |mod| require "#{File.dirname(__FILE__)}/#{mod}"}

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
  
  def MinimalMatch.flatten_match_array ma
    MinimalMatch::MatchMultiplying.flatten_match_array ma
  end  
  
  def =~ match_array
    match_array = MinimalMatch.flatten_match_array match_array 
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
      
      # make sure the beginnings match
      pos = match_array[0].length 
      search_arr = match_self[0..pos-1]
      
      #an empty array matches anything , whichis the case for a leading
      # glob 
      return false unless search_arr =~ match_array.shift

      match_array.each do |ma|
        # find the first occurence of the remaining match pattern
        # sections in self 
        # ie
        # [1,2,3,4,5,6,7,8] = [[5,6],[8]]
        # would find the five and return "6" for the place
        # to start looking for matches again.
        first_match = match_self[pos..-1].index(ma[0])
        unless first_match
          # it was not found
          # if the last element is an emty array then
          # we know we are a match
          return true if match_array.last == [] 
          # otherwise, we are matching as the last element
          # before a sub match and need to make sure that
          # subelement matches.
          return (match_self[-1] =~ ma[0] || false)
        else
          # the first place we have a match
          first_match += pos
        end
        # expand the match array to be as long
        # as the search_array
        search_arr = match_self[pos..first_match+ma.length]
        (search_arr.length - ma.length).times do
          ma.unshift(ma.type)
        end
        # and run the regular match routin on them.
        return false unless search_arr =~ ma
        # if we're still a match, move on the next position
        # and keep looking
        pos = first_match + ma.length 
      end
      return true
    end
       
    match_array.zip(match_self) do |comp|
      if comp[0].is_a? Array and comp[1].is_a? Array
        return false unless comp[1] =~ comp[0]
      else 
        # comp 0 is our comparison array, comp[1] is us.
        # the case quality operator is not commutative
        # so it's got to be in this order
        unless comp[0] === comp[1]
          return false
        end 
      end
    end
    true
  end
end
