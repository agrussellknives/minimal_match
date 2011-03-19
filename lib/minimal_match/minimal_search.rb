require 'delegate'

module MinimalMatch
  module MinimalSearchMixin
    def search match
      MinimalMatch::MinimalSearch.new(self, :autoextend).find(match)
    end
  end

  class MinimalSearch < SimpleDelegator 
    
    class SearchEnumerator < Enumerator
      include MinimalSearchMixin
      attr_accessor :search_term

      def to_s 
        "#<#{self.class}:0x#{'%x' % self.object_id << 1} search_term: #{@search_term}>"
      end
    end

    def initialize array, autoextend=true
      begin 
        @array = array.to_a
      rescue TypeError => e
        raise TypeError, "#{array.class} can't be converted to an array"
      end
      @autoextend = autoextend ? true : false
      unless @array.method(:=~).owner == MinimalMatch
        @array.extend MinimalMatch
      end
      @en = SearchEnumerator.new {}
      super(@en) # just blank for nowi
    end

    def find match 
      @en = SearchEnumerator.new do |y|
        class_look = lambda do |expression|
          if expression =~ match
            y.yield expression
          end
          expression.each do |subexp|
            if subexp.method(:=~).owner == MinimalMatch
              class_look.call(subexp)
            elsif @autoextend
              if subexp.kind_of? Array
                subexp.extend MinimalMatch
                redo 
              end
            end
          end
        end
        class_look.call(@array)
      end
      @en.search_term = match
      __setobj__ @en
    end

    def to_s
      "#<#{self.class}:0x#{'%x' % self.object_id << 1} array: #{@array}>"
    end

    def inspect
      to_s
    end
  end
end

#  vim: set ts=2 sw=2 tw=0 :
