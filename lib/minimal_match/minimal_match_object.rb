module MinimalMatch
  # module which provdes the compile method
  # in order to return custom bytecodes for itself
  # a minimal match object should implement the _compile
  # method
  module MatchCompile
  #bytecodes and their arity
  BYTECODES = {
   split: 2,
   lit: 1,
   jump: 1,
   noop: 0,
   peek: 1,
   save: 1,
   match: 0
  }
  #BYTECODES = [:split,:lit,:jump,:save,:match]   
    def compile at_index=nil, obj=nil
      # for match proxies respond to goes to the subject
      # so we try this and catch the error 
      begin
        r = self._compile(at_index || 0)
      rescue NoMethodError => e
        raise e unless e.name == :_compile #pass any other exception
        r = if obj and is_proxy? obj
          [:lit, obj.comp_obj]
        elsif not obj and is_proxy? self
          [:lit, @comp_obj]
        else
          [:lit, obj]
        end
      end
    end
    module_function :compile
    public :compile

    def flatten_compile arr
      p arr
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
          res.concat flatten_compile i 
        end
      end
      res
    end
    module_function :flatten_compile
  end
  MatchCompile.extend MinimalMatch::ProxyOperators

  # provides introspect capabilities for matchobject heirarcy
  class MinimalMatchObject < BasicObject
    # Abstract
    #
    def MinimalMatchObject.const_missing const
      puts "#{const} missing in matchobject heir #{const}"
    end

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
    end
    private :initialize

    def kind_of? klass
      return true if @ancestry.include? klass
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

    # these are not just aliased, because we undef
    # to_s in the proxy classes, but not inspect
    def to_s
      @klass.to_s
    end

    def inspect
      @klass.to_s
    end

    def _compile(*)  #who cares
      [:lit, self]
    end
    
  end
  # since you can't look up the module from that scope
  MinimalMatchObject.send :include, Kernel # so you can raise, etc

  # enable the is_proxy? test-like-thingy in matchobjects
  MinimalMatchObject.send :include, MinimalMatch::ProxyOperators
  MinimalMatchObject.send :include, MinimalMatch::ToProxy # WHOA, DID YOU SEE YOUR MIND GET BLOWN
  MinimalMatchObject.send :include, MinimalMatch::MatchCompile
  MinimalMatchObject.send :include, MinimalMatch::Debugging


  class AbstractMatchProxy < MinimalMatchObject
    attr_accessor :comp_obj

    # undef MOST of the introspection capabilities to pass them
    # on to the subject
    undef_method :to_s, :respond_to?, :is_a?, :class rescue nil

    def initialize klass = nil
      super(klass)
      @is_proxy = true #always!
    end

    def to_s
      "#{@comp_obj.to_s}"
    end

    def === val
      # enables classification if we are proxying a class object
      # doesn't work the other direction.  TFS
      @comp_obj.__send__ :===, val
    end

    def respond_to_missing? meth, *args
      puts "respond to missing from abstract match proxy"
    end

    def method_missing meth, *args
      raise "How did you instantiate this object? This is an abstract."
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
  
  # so you can call it while you're debugging
end 
#  vim: set ts=2 sw=2 tw=0 :
