require 'fiber'

# An enumerator that can go forward and backward
class ReversibleEnumerator 
  # @arguments
  def initialize obj, no_duplicate = false
    @index = -1 
    @obj = no_duplicate ? obj : obj.dup.freeze #if passed the duplicate param then dup the iterable
    @fiber = Fiber.new(&(method(:__block)))
    @ref_hash = @obj.hash
    @run_once = false
  end

  def to_s
    "#<ReverseEnumerator:#{'%x' % self.__id__ << 1}} #{obj.to_s}"
  end

  def __block op
    while true
      case op
        when :current
          op = Fiber.yield @obj[@index]
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
  end
  private :__block

  def method_missing meth
    raise MethodNotFound unless [:current,:next,:prev,
      :rewind,:fast_foward,:peek,:back_peek].include? meth
   
    if @ref_hash != @obj.hash #our object has changed
      @ref_hash = @obj.hash
      if @last_obj
        @index = @obj.index @last_obj
      else
        raise RuntimeError, "Iterable object modified before enumerator started."
      end
      raise RuntimeError, "Cannot find current object in Enumerator." if @index.nil?
    end
    
    unless @fiber.alive?
      @fiber = Fiber.new(&(method(:__block)))
    end
   
    @fiber.resume meth
  end
  
  def end?
    !(!!self.peek) rescue true
  end

  def begin?
    !(!!self.back_peek) rescue true
  end
end

