module MinimalMatch
  # module which provdes the compile method
  # in order to return custom bytecodes for itself
  # a minimal match object should implement the _compile
  # method
  module MatchCompile
  extend ::MinimalMatch::ProxyOperators
  #bytecodes and their arity
  BYTECODES = {
   split: 2,
   lit: 1,
   jump: 1,
   noop: 0,
   peek: 1,
   hold: 1,
   save: 1,
   match: 0
  }
  #BYTECODES = [:split,:lit,:jump,:save,:match]   
    def compile at_index=nil, obj=self
      # for match proxies respond to goes to the subject
      # so we try this and catch the error 
      begin
        r = obj._compile(at_index || 0)
      rescue NoMethodError => e
        raise e unless e.name == :_compile #pass any other exception
        r = [:lit, obj]
      end
      normalize_compile r
    end
    module_function :compile
    public :compile

    def normalize_compile arr
      arr = arr.each
      res = []
      loop do
        i = arr.next
        #account for literal match for a bytecode symbol
        if (BYTECODES.keys.include?(i.first) rescue false)
          res.push(i)
        elsif BYTECODES.keys.include?(i)
          t = [i] 
          BYTECODES[i].times do
            t << arr.next
          end
          res.push(t)
        else
          res.concat normalize_compile i 
        end
      end
      res
    end
    module_function :normalize_compile
  end
  
  # provides introspect capabilities for matchobject heirarcy
  class MinimalMatchObject < BasicObject
    #undef remaining methods to so they get passed on to the subject 
    include ::Kernel
    include ::MinimalMatch::ProxyOperators
    include ::MinimalMatch::ToProxy
    include ::MinimalMatch::MatchCompile
   
    # Abstract
    def class
      class << self
        self.superclass
      end
    end
    
    def initialize(klass=false)
      @ancestry = []
      superclass = @klass = klass || self.class
      while superclass do
        @ancestry << superclass if superclass
        superclass = superclass.superclass
      end
      @ancestry.uniq!
      @is_match_op = true
    end
    private :initialize

    def kind_of? klass
      return true if @ancestry.include? klass
      debugger
      if (icm = @klass.included_modules) # yes, that's supposed ot be an assignment
        return true if icm.include? klass
      end
      false
    end

    def respond_to? meth
      #singleton class calls this for some reason.
      self.class.instance_methods.include? meth
    end

    def is_a? klass 
      @klass == klass
    end

    def inspect 
      @klass.to_s
    end

    def == other
      self.compile == other.compile
    end
    
    #rspec expects there to ba pretty print method,
    #but the stdlib one doesn't work on anything
    #not descended from Object, here is a simple implementation
    # it prints the compiled version of the object
    def pretty_print q
      compiled = self.compile
      compiled.each_with_index do |c,i|
        q.breakable
        q.text "#{'%03d' % i}: #{c}"
      end
      q
    end 
    
    def _compile(*)  #who cares
      [:lit, self]
    end
    
  end
  # since you can't look up the module from that scope
 
  class AbstractMatchProxy < MinimalMatchObject
    attr_accessor :comp_obj

    #undef our heirarchy's introspection stuff
    undef_method :to_s, :respond_to?, :is_a?, :class, :==, :!=

    def initialize klass = nil
      super(klass)
      @is_proxy = true #always!
    end

    def to_s
      "#{@comp_obj.to_s}"
    end

    def to_obj
      begin
        @comp_obj.dup
      rescue ::TypeError => e
        return @comp_obj if e.message =~ /can't dup/
        raise e
      end
    end

    def === val
      # enables classification if we are proxying a class object
      # doesn't work the other direction.  TFS
      @comp_obj.__send__ :===, val
    end

    def respond_to_missing? meth, *args
      raise "Method #{meth} looked for in abstract class."
    end

    def pass meth, *args
      method_missing meth, *args
    end

    def coerce arg
      arg_equiv = is_proxy?(arg) ? arg.comp_obj : arg
      self_equiv, arg_equiv = super
      return self_equiv, arg_equiv
    end

    def method_missing meth, *args
      raise "Method #{meth} called in abstract class."
    end

    def _compile(idx = 0) #support nested single proxies
      # no method error will be caught by "compile"
      if is_proxy? @comp_obj or is_match_op? @comp_obj
        @comp_obj._compile(idx+1) # so, like not including myself natch
      else
        [:lit, @comp_obj]
      end
    end
        
    private :initialize
  end
end 
#  vim: set ts=2 sw=2 tw=0 :
