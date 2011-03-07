module MinimalMatch

  # Array::Anything.  it will always be equal to whatever you compare it to 
  class Anything < BasicObject
     def Anything.flatten_match_array ma
      ma.inject([]) do |m,o|
        if o.instance_variable_get :@match_array
          m.concat o
        else
          m << o 
        end
      end
     end 
      
    class << self
      def === who_cares
        true
      end
      
      def to_a 
        [AnyNumberOfThings]
      end

      def * num
        raise ArgumentError, "can't multiply by non Fixnum #{num}" unless num.is_a? Fixnum
        k = []
        num.times do
          k << Anything
        end
        k.instance_variable_set :@match_array, true
        return k 
      end

      def coerce other
        return self,other
      end
        
    end
  end

  class AnyOf < BasicObject
    class << self
      def [] *args
        self.new(args)
      end
    end
    def initialize(args)
      @match_arr = args
    end

    def method_missing meth, *args
      nil
    end

    def class
      AnyOf
    end
    
    def inspect
      "#{self.class}:#{@match_arr.to_s}"
    end

    def === obj
      @match_arr.each do |m|
        return true if m == obj
      end
      false
    end
  end

  class AnyNumberOfThings < Anything; end

  class << AnyNumberOfThings
    undef_method :*
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
  
  def =~ match_array
    match_array = Anything.flatten_match_array match_array 
    
    if self.length < match_array.length
       return false
    end
    
    if match_array.include? AnyNumberOfThings
      #divide the match array into subarrays, splitting on AnyNumberOfThings
      # [ *anything, 5, *anything, 8] becomes
      # [[5],[8]]
      match_array = match_array.inject([[]]) do |res,el|
        if el == AnyNumberOfThings
          res << [] 
        else
          if el.is_a? Array
            el.instance_variable_set :@recursed, true
          end
          res.last << el
        end
        res
      end
      
      # make sure the beginnings match
      pos = match_array[0].length 
      search_arr = self[0..pos-1]
      return false unless search_arr =~ match_array.shift

      match_array.each do |ma|
        # find the first occurence of the remaining match pattern
        # sections in self 
        # ie
        # [1,2,3,4,5,6,7,8] = [[5,6],[8]]
        # would find the five and return "6" for the place
        # to start looking for matches again.
        first_match = self[pos..-1].index(ma[0])
        unless first_match
          # it was not found
          # if the last element is an emty array then
          # we know we are a match
          return true if match_array.last == [] 
          # otherwise, we are matching as the last element
          # before a sub match and need to make sure that
          # subelement matches.
          return (self[-1] =~ ma[0] || false)
        else
          # the first place we have a match
          first_match += pos
        end
        # expand the match array to be as long
        # as the search_array
        search_arr = self[pos..first_match]
        (search_arr.length - 1).times do
          ma.unshift Anything
        end
        # and run the regular match routin on them.
        return false unless search_arr =~ ma
        # if we're still a match, move on the next position
        # and keep looking
        pos = first_match + 1
      end
      return true
    end
       
    match_array.zip(self) do |comp|
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
