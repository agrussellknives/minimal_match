module MinimalMatch
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
    
  end
  # since you can't look up the module from that scope
  MinimalMatchObject.send :include, Kernel # so you can raise, etc
  # enable the is_proxy? test-like-thingy in matchobjects
  MinimalMatchObject.send :include, MinimalMatch::ProxyOperators

  class AbstractMatchProxy < MinimalMatchObject
    attr_accessor :comp_obj
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
    
    private :initialize
  end
end 
#  vim: set ts=2 sw=2 tw=0 :
