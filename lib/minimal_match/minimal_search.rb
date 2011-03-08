module MinimalMatch
  class MinimalSearch 
    def initialize array
      unless array.kind_of? Array
        raise ArgumentError, "I only know how to search Arrays not #{array.class}" 
      end

      # add the matchin facility to the array if necessary
      unless array.method(:=~).owner == MinimalMatch
        array.extend MinimalMatch
      end
      @array = array
    end

    def find match
      # i imagine we can cache the enumerator here
      #rewrite to use enumerator
      @matches = Enumerator.new do |y| 
        class_look = lambda do |expression|
          y.yield expression if match.is_like? expression
          expression.each do |e| 
            if e.is_a? Array
              class_look.call(e)
            end
          end
        end
        class_look.call(@array)
      end
      @matches
    end

    def pos
      @matches
    end

    def pos= old_exp
      @matches = old_exp
    end

    def rewind
      @matches = nil 
    end

    def to_a
      @matches
    end
  end
end
