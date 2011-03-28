module MinimalMatch
  class ArrayMatchData
    def initialize(array, pattern, f_index, e_index)
      @first_index = f_index
      @end_index = e_index
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
      "#<#{'0x' % self.id << 1} pattern: #{@pattern} array: #{@array} begin: #{@first_index} end: #{@end_index}>"
    end

    def length
      @end_index - @first_index
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
