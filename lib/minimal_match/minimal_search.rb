module MinimalMatch
  class MinimalSearch 
    def initialize array 
      raise ArgumentError, "I only know how to search Arrays not #{array.class}" unless array.kind_of? Array
      unless array.method(:=~).owner == MinimalMatch
        array.extend MinimalMatch
      end
      @array = array
    end

    def find match 
      expressions = []
      @matches = Enumerator.new do |y|
        class_look = lambda do |expression|
          if match.is_like? expression
            y.yield expression
            if expression.is_a? Array
              class_look.call(expression)
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
