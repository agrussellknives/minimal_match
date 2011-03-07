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
      #rewrite to use enumerator
      @matches ||= @array
      expressions = []
      class_look = lambda do |expression|
        expressions << expression if match.is_like? expression
        expression.each do |e| 
          if e.is_a? Array
            class_look.call(e)
          end
        end
      end
      class_look.call(@matches)
      @matches = expressions
      self
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
