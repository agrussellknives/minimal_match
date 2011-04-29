module MinimalMatch
  class ArrayMatchData
    def initialize(array, pattern)
      @first_index = nil 
      @end_index = nil 
      @array = array
      @pattern = pattern
    end

    def ==(mtch2)
      mtch2.begin == @first_index && mtch2.end == @end_index && mtch2.pattern == @pattern && mtch.array == @array
    end

    def begin
      @first_index
    end

    def end
      @end_index
    end

    def inspect
      # recompile pattern to string leaving off the unanchored matches
      p_string = @pattern.map(&:to_s)
      "#<ArrayMatchData:0x#{'%x' % (self.__id__ << 1)} pattern: #{p_string} array: #{@array[0..-2]} begin: #{@first_index} end: #{@end_index}>"
    end

    def length
      (@end_index - @first_index) + 1 # inclusive
    end

    def post_match
      @array[@end_index..-1]
    end

    def pre_match
      @array[0..@first_match]
    end

    def pattern
      @pattern
    end

    def array
      @array.dup.freeze
    end

    # deals with multiple matches, which we don't
    # support... yet
    [:[], :captures, :names, :offset, :to_a, :to_s,
     :values_at].each do |m|
      define_method m do |*args|
        raise NotImplementError
      end
    end

    # things that maybe we implement later
    #- (Array) captures
    #Returns the array of captures; equivalent to mtch.to_a.

    #- (Array) names
    #Returns a list of names of captures as an array of strings.

    #- (Array) offset(n)
    #Returns a two-element array containing the beginning and ending offsets of the nth match.

    #- (Regexp) regexp
    #Returns the regexp.
    #- (Object) size
    #Returns the number of elements in the match array.

    #- (Array) to_a
    #Returns the array of matches.

    #- (String) to_s
    #Returns the entire matched string.

    #- (Array) values_at([index])
    #Uses each index to access the matching values, returning an array of the corresponding matches.
  end
end
