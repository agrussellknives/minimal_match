module MinimalMatch
  class ArrayMatchData
    attr_accessor :sub_match

    def initialize(array, pattern)
      @first_index = nil 
      @end_index = nil 
      @array = array[0..-2].freeze #drop the sentinel
      @pattern = pattern.dup.freeze
      @captures = {}
      @sub_match = {}
    end

    def ==(mtch2)
      mtch2.begin == @first_index && mtch2.end == @end_index && mtch2.pattern == @pattern && mtch.array == @array
    end

    def begin
      return @begin if @begin
      beg = 1.0/0
      @captures.each do |k,v|
        beg = v[:begin] < beg ? v[:begin] : beg
      end
      @begin = beg
    end

    def end
      return @end if @end
      endd = 0
      @captures.each do |k,v|
        endd = v[:end] > endd ? v[:end] : endd
      end
      @end = endd
    end

    def inspect
      # recompile pattern to string leaving off the unanchored matches
      p_string = @pattern.to_s
      "#<ArrayMatchData:0x#{'%x' % (self.__id__ << 1)} pattern: #{p_string} array: #{@array} begin: #{self.begin} end: #{self.end}>"
    end

    def length
      (@end - @begin) + 1 # inclusive
    end

    def post_match
      @array[@end+1..-1]
    end

    def pre_match
      @array[0..@begin-1]
    end

    def pattern
      @pattern
    end

    def array
      @array
    end

    def captures
      @captures.each_with_object [] do |k,v,memo|
        if not k.is_a? Fixnum
          memo << [k, [@array[v[:begin] .. v[:end]]]]
        else
          memo << @array[v[:begin] .. v[:end]]
        end
      end
    end

    def names
      @captures.keys.select { |i| not i.is_a? Fixnum }
    end
    
    #- (Array) offset(n)
    #Returns a two-element array containing the beginning and ending offsets of the nth match.
    def offset n
      b,e = @captures[n][:begin], @captures[n][:end]
      [b,e]
    end

    def size
      @captures.size
    end

    #- (Array) to_a
    #Returns the array of matches.
    def to_a
      @captures.collect do |k,v|
        @array[v[:begin] .. v[:end]]
      end
    end

    #- (String) to_s
    #Returns the entire matched string.
    def values_at(*args)
      self.to_a.values_at(*args)
    end
  end
end
