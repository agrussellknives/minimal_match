require 'delegate'

module MinimalMatch
  module MinimalSearchMixin
    def search match
      MinimalMatch::MinimalSearch.new(self).find(match)
    end
  end

  class MinimalSearch < SimpleDelegator 
    def initialize array
      begin 
        @array = array.to_a
      rescue TypeError => e
        raise TypeError, "#{array.class} can't be converted to and array" 
      end

      unless array.method(:=~).owner == MinimalMatch
        array.extend MinimalMatch
      end
      @array = array
      super(Enumerator.new) # just blank for now
    end

    def find match 
      @en = Enumerator.new do |y|
        class_look = lambda do |expression|
          if expression =~ match
            y.yield expression
          end
          expression.each do |subexp|
            if subexp.method(:=~).owner == MinimalMatch
              class_look.call(subexp)
            end
          end
        end
        class_look.call(@array)
      end
      @en.singleton_class.send :define_method, :search do
        match
      end
      __setobj__ @en
      self 
    end

    def inspect
      "#<#{self.class} search: #{@en.search}>"
    end

  end
end

#  vim: set ts=2 sw=2 tw=0 :
