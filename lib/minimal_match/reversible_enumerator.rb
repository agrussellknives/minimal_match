require 'fiber'
require 'benchmark'

class Array
  def __rev_en_block op, arg = nil
    # it seems like it's this, C, or implementing some kind of aspect
    
    index ||= -1
    while true
      $stdout.puts "in fiber #{Fiber.current} with #{op}, #{arg} at #{index}" 
      case op
        when :index, :index=
          if arg 
            index = arg
            op, arg = Fiber.yield nil 
          else
            raise StopIteration unless (-1 .. self.length).include? index
            op, arg = Fiber.yield index
          end
        when :next
          index += 1
          op = :yield
        when :prev
          index -= 1
          op = :yield
        when :yield, :current
          raise StopIteration unless (0 .. self.length-1).include? index
          op, arg = Fiber.yield self[index] 
        when :rewind
          index = -1
          op, arg = Fiber.yield nil 
        when :fast_foward
          index = length
          op, arg = Fiber.yield nil 
        when :peek
          pi = index + 1
          op = :peek_yield
        when :back_peek
          pi = index - 1
          op = :peek_yield
        when :peek_yield
          raise StopIteration unless (0 .. self.length-1).include? pi 
          op, arg = Fiber.yield self[pi] 
        when :reset
          break
        else
         raise NoMethodError, "#{self.class} ReversibleEnumerator does not respond to #{op}"
      end
    end
    #$stdout.puts "last statment in block"
    ensure
      if index > length
        index = length
      elsif index < -1
        index = -1
      end
      $!.result = index if StopIteration == $!
  end
  private :__rev_en_block
end

class StopIteration < IndexError
  attr_accessor :result
end

# An enumerator that can go forward and backward
class ReversibleEnumerator
  # @arguments

  attr_reader :obj 

  #TODO, make it handle strings, etc. anything that responds to arbitrary indexing

  def initialize obj, no_duplicate = false
    raise ArgumentError,"Object must be enumerable" if not obj.kind_of? Enumerable
    @index = -1 
    @obj = no_duplicate ? obj : obj.dup #if passed the duplicate param then dup the iterable
    define_singleton_method(:__block, &(@obj.method :__rev_en_block))
    @fiber = Fiber.new(&(method(:__block)))
    @ref_hash = @obj.hash if no_duplicate #we'll have to know if we duplicate this
  end

  def initialize_copy other 
    if other.instance_eval { @ref_hash }
      @obj = other.obj
    else
      @obj = other.obj.dup
    end
    #copy the method from the other enumerator
    define_singleton_method(:__block, &(other.method(:__block)))

    @fiber = Fiber.new(&(method(:__block)))
    @ref_hash = @obj.hash
    last_index = nil
    other.instance_eval do
      last_index = @fiber.resume(:index) rescue $!.result
    end
    $stdout.puts last_index
    @fiber.resume :index=, last_index
  end

  def to_s
    "#<ReversibleEnumerator:#{'0x%x' % (self.__id__ << 1)} #{@obj.to_s}>"
  end

  def to_a
    @obj
  end

  def method_missing meth, *args
    if @ref_hash and @ref_hash != @obj.hash #our object has changed
      @ref_hash = @obj.hash
      if (obj = @fiber.resume(:yield))
        index = @obj.index obj 
      else
        #should this be an error?
        raise RuntimeError, "Iterable object modified before enumerator started."
      end

      if index.nil?
        raise RuntimeError, "Cannot find current object in Enumerator."
      else
        @fiber.resume :index=, index
      end
    end
   
    unless @fiber.alive?
      $stdout.puts "making new fiber"
      @fiber = Fiber.new(&(method(:__block)))
      @fiber.resume :index=, @index
    end

    begin 
      res = @fiber.resume meth, *args
      $stdout.puts "saving index after #{meth}"
      @index = @fiber.resume :index
    rescue StopIteration => e
      @index = e.result
      raise e
    end
    res
  end

  def grab
    warn "Point of ReversibleEnumerator subverted!"
    @fiber = Fiber.new(&(method(:__block)))
    @fiber.resume :index=, @index
    @fiber.alive? ? true : false  # just to be explicit
  end

  def [] arg
    self.index = arg 
    self.current
  end

  def end?
    return false if self.peek
  rescue StopIteration
    true
  end

  def begin?
    return false if self.back_peek
  rescue StopIteration
    true
  end

end

