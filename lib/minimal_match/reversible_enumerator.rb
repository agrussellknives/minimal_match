require 'fiber'

# An enumerator that can go forward and backward
class ReversibleEnumerator 
  # @arguments

  @@valid_methods = [:next,:prev,:rewind,:fast_foward,:peek,:back_peek,:reset]

  attr_reader :obj, :index

  #TODAY, make it handle strings, etc. anything that responds to arbitrary indexing

  def initialize obj, no_duplicate = false
    raise ArgumentError,"Object must be enumerable" if not obj.kind_of? Enumerable
    @index = -1 
    @obj = no_duplicate ? obj : obj.dup #if passed the duplicate param then dup the iterable
    @fiber = Fiber.new(&(method(:__block)))
    @ref_hash = @obj.hash if no_duplicate #we'll have to know if we duplicate this
  end

  def initialize_copy other 
    if other.instance_eval { @ref_hash }
      @obj = other.obj
    else
      @obj = other.obj.dup
    end
    @fiber = Fiber.new(&(method(:__block)))
    @ref_hash = @obj.hash
    @index = other.instance_eval { @index } # don't care if it's out of range
  end

  def to_s
    "#<ReversibleEnumerator:#{'0x%x' % (self.__id__ << 1)} #{@obj.to_s}>"
  end

  def to_a
    @obj
  end

  def __block op
    # it seems like it's this, C, or implementing some kind of aspect
    while true
      case op
        when :next
          @index += 1
          op = :yield
        when :prev
          @index -= 1
          op = :yield
        when :yield
          raise StopIteration unless (0..@obj.length-1).include? @index
          @last_obj = @obj[@index]
          op = Fiber.yield @last_obj 
        when :rewind
          @index = -1
          op = nil
        when :fast_foward
          @index = @obj.length
          op = nil
        when :peek
          pi = @index + 1
          op = :peek_yield
        when :back_peek
          pi = @index - 1
          op = :peek_yield
        when :peek_yield
          raise StopIteration unless (0..@obj.length-1).include? pi 
          op = Fiber.yield @obj[pi] 
        when :reset
          break
        else
          op = Fiber.yield nil
      end
    end
    ensure
      if @index > @obj.length
        @index = @obj.length
      elsif @index < -1
        @index = -1
      end
    self
  end
  private :__block


  def method_missing meth
    unless @@valid_methods.include? meth
      raise NoMethodError, "ReversibleEnumerator does not respond to #{meth}"
    end

    if @ref_hash and @ref_hash != @obj.hash #our object has changed
      @ref_hash = @obj.hash
      if @last_obj
        @index = @obj.index @last_obj
      else
        #should this be an error?
        raise RuntimeError, "Iterable object modified before enumerator started."
      end

      if @index.nil?
        @index = -1
        raise RuntimeError, "Cannot find current object in Enumerator."
      end
    end
    
    unless @fiber.alive?
      @fiber = Fiber.new(&(method(:__block)))
    end
   
    @fiber.resume meth
  end

  def grab
    warn "Point of ReversibleEnumerator subverted!"
    begin
      @fiber.resume :reset
    rescue FiberError
      @fiber = Fiber.new(&(method(:__block)))
      retry
    end
    @fiber.alive? ? true : false  # just to be explicit
  end

  def index= arg
    if not @fiber.alive?
      @fiber = Fiber.new(&(method(:__block))) 
    end
    @index = arg
    @fiber.resume :reset # will raise FiberError if done across a thread
    # this method will always return arg.  it's pretty much
    # unavoidable.
  end

  def [] arg
    self.index = arg 
    self.current
  end

  def index
    raise StopIteration unless (0..@obj.length-1).include? @index
    @index
  end

  def current
    raise StopIteration unless (0..@obj.length-1).include? @index
    @obj[@index]
  end

  def end?
    !(!!self.peek) rescue true
  end

  def begin?
    !(!!self.back_peek) rescue true
  end

end

