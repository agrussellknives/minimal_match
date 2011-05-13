require 'singleton'

module MinimalMatch
  module ToProxy
    def to_m
      r = MinimalMatch::MatchProxy.new(MinimalMatch::NoOp)
      this = self
      r.instance_eval do
        @comp_obj = this #closures rock my world
      end
      r
    end
  end

  module Debugging
    class BlackHole < BasicObject #lo i am become blackhole, eater of messages
      include ::Singleton
      include ::Kernel
      def method_missing m, *args
        yield *args if block_given?
        self
      end
    end
    
    def self.included receiver
      receiver.extend ClassMethods
    end
    
    module ClassMethods
      def debug?
        @debug || false
      end

      def debug= arg
        @debug = arg
      end

      def debug_delay arg=nil
        @debug_delay ||= 0.25
        unless arg then @debug_delay else @debug_delay = arg end
      end
    end
    
    def debug(prog = nil,subj = nil)
      return BlackHole.instance unless self.class.debug? 
      @debugger ||= _newdebugger(prog,subj)
    end

    def _newdebugger(prog,subj)
      d = self.class.debug_class.new(prog,subj)
      d.delay = self.class.debug_delay 
      d
    end
  end

  module ProxyOperators
    # it's easier to just set this directly on these objects
    # rather than to construct the heuristic for determining
    # the classification and having to update it when
    # we want to add new operators
    def is_proxy? obj
      obj.instance_variable_get :@is_proxy
    end
    module_function :is_proxy?

    def is_match_op? obj
      obj.instance_variable_get :@is_match_op
    end
    #because i keep typing it wrong
    alias :is_match_obj? :is_match_op?
    module_function :is_match_op?

    def is_group? obj
      obj.instance_variable_get :@is_group
    end
    module_function :is_group?
  end

  def m(*args,&block)
    if block_given?
      raise ArgumentError, "Block supplied - didn't expect arguments" unless args.empty?
      MinimalMatch::MatchProxy.new(block) # pass block as argument and not as block 
    else
      raise ArgumentError, "Wrong number of arguments 0 for ..." if args.empty?
      if args.length == 1 || args.nil?
        val = args.nil? ? nil : args[0]
        MinimalMatch::MatchProxy.new(val)
      else
        MinimalMatch::MatchProxyGroup.new(*args)
      end
    end
  end
  module_function :m
end

require_relative 'minimal_match/minimal_match'
require_relative 'minimal_match/minimal_search'

#remove this!
require_relative 'minimal_match/kernel'
require_relative 'minimal_match/debug_machine'
