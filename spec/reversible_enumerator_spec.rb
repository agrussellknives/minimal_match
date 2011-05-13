require_relative '../lib/minimal_match/reversible_enumerator'

describe "it's a reversible enumerator" do
  before :all do
    @array = [1,2,3,4,5]
  end

  it "can duplicate itself" do
    en = ReversibleEnumerator.new @array
    en2 = en.dup
    2.times { en.next }
    en.next.should == 3
    4.times { en2.next }
    en2.current.should == 4
    en2.prev.should == 3
    en.fast_foward
    en2 = en.dup
    lambda { en.next }.should raise_error StopIteration
  end

  it "knows when it's at the beginning or end" do
    en = ReversibleEnumerator.new @array
    loop { en.next }
    en.end?.should == true
    loop { en.prev }
    en.begin?.should == true
  end

  it "goes forward" do
    en = ReversibleEnumerator.new @array
    1.upto 5 do |i|
      en.next.should == i
    end
  end
  
  it "goes backward" do
    en = ReversibleEnumerator.new @array
    loop { en.next }
    5.downto 1 do |i|
      en.prev.should == i
    end
  end

  it "can assign an index" do
    en = ReversibleEnumerator.new @array
    en.index = 3
    en.current.should == 4
    en.next.should == 5
  end

  it "rewinds" do
    en = ReversibleEnumerator.new @array
    loop { en.next }
    en.end?.should == true
    en.rewind
    en.begin?.should == true
    en.next.should == 1
  end

  it "fast-fowards" do
    en = ReversibleEnumerator.new @array
    en.begin?.should == true
    en.fast_foward
    en.end?.should == true
    en.prev.should == 5
  end

  
  it "raises stop iteration on past end" do
    en = ReversibleEnumerator.new @array
    lambda { 6.times { en.next }}.should raise_error StopIteration
  end

  it "raises stop iteration on before beginning" do
    en = ReversibleEnumerator.new @array
    5.times { en.next }
    lambda { 6.times { en.prev }}.should raise_error StopIteration
  end

  it "will return current" do
    en = ReversibleEnumerator.new @array
    3.times { en.next }
    en.current.should == 3
  end

  it "is iterable even after it's raised" do
    en = ReversibleEnumerator.new @array
    begin
      6.times { en.next }
    rescue StopIteration
    end

    en.prev.should == 5

    begin
      6.times { en.prev }
    rescue StopIteration
    end
    
    en.next.should == 1
  end

  it "peeks" do
    en = ReversibleEnumerator.new @array
    1.upto 2 do |i|
      en.next.should == i
    end
    en.peek.should == 3
    en.back_peek.should == 1
    en.next.should == 3
    en.prev.should == 2
  end

  describe "deals with mutable underlying objects" do

    it "can do that even if you didn't start out that way" do
      @array2 = [1,2,4,5,6]
      en = ReversibleEnumerator.new @array2
      en.next.should == 1
      # oh noes, I forgot the 3
      en.obj.insert(2,3)
      en.next.should == 2
      en.next.should == 3
    end

    it "only dups the enumerator itself if you specifiy no_duplicate" do
      array2 = [1,4,5,6]
      en = ReversibleEnumerator.new array2, :no_duplicate
      en2 = en.dup
      en.next.should == 1
      en2.next.should == 1
      en.obj.insert(1,2)
      en2.next.should == 2
      en2.obj.insert(2,3)
      en.next.should == 2 
      en.next.should == 3
    end

    it "can account for appending things on the end" do
      arr = @array.dup
      en = ReversibleEnumerator.new arr, :no_duplicate
      en.next.should == 1
      arr << 6
      loop { en.next }
      en.prev.should == 6 
    end

    it "can account for appending things after StopIteration" do
      arr = @array.dup
      en = ReversibleEnumerator.new arr, :no_duplicate
      loop { en.next }
      arr << 6
      en.next.should == 6
    end

    it "can account for unshifting" do
      arr = @array.dup
      en = ReversibleEnumerator.new arr, :no_duplicate
      en.next.should == 1
      arr.unshift 0
      en.prev.should == 0
    end

    it "can account for unshifting after stopiteration" do
      arr = @array.dup
      en = ReversibleEnumerator.new arr, :no_duplicate
      en.next.should == 1
      arr.unshift 0
      en.prev.should == 0
    end

    it "can modify the array around the current position" do
      arr = @array.dup
      en = ReversibleEnumerator.new arr, :no_duplicate
      2.times { en.next }
      en.current.should == 2
      arr2 = arr.slice!(2..-1)
      arr.concat [2.5, 2.6, 2.7]
      arr.concat arr2
      en.next.should == 2.5
      en.next.should == 2.6
      en.next.should == 2.7
      en.next.should == 3
      arr.slice!(5..-1)
      lambda { en.prev }.should raise_error RuntimeError
    end

    it "supports insert" do
      arr = @array.dup
      en = ReversibleEnumerator.new arr, :no_duplicate
      2.times { en.next }
      en.current.should == 2 #yeah but it's INDEX 1
      arr.insert(en.index.succ,'a','b')
      en.next.should == 'a'
      en.next.should == 'b'
    end

    it "supports slice" do
      arr = @array.dup
      en = ReversibleEnumerator.new arr, :no_duplicate
      2.times { en.next }
      arr.slice!(en.index.succ..-2) #leave the last one
      en.next.should == 5 
    end

    it "modifiyng the object before iteration is an error" do
      arr = @array.dup
      en = ReversibleEnumerator.new arr, :no_duplicate
      arr.unshift 0
      lambda { en.prev }.should raise_error RuntimeError
    end

    it "removing the current object is also an error" do
      arr = [1,2,3,4]
      en = ReversibleEnumerator.new arr, :no_duplicate
      en.next.should == 1
      en.current.should == 1
      arr.shift
      lambda { en.next }.should raise_error RuntimeError
    end
  end

  it "can have immutable object" do
    arr = @array.dup
    en = ReversibleEnumerator.new arr
    lambda { 6.times { en.next }}.should raise_error StopIteration
    arr << 6
    lambda { en.next }.should raise_error StopIteration
    arr.unshift 3
    5.times { en.prev }
    lambda { en.prev }.should raise_error StopIteration
  end

  it "won't let you touch it from another thread" do
    en2 = nil 
    s = Thread.new do
      en2 = ReversibleEnumerator.new @array
      en2.next
    end
    s.join # ensure it starts on the other thread
    lambda { en2.next }.should raise_error FiberError
  end

  it "can't assign index from other thread" do
    en3 = nil
    s = Thread.new do
      en3 = ReversibleEnumerator.new @array
      en3.next
    end
    s.join
    lambda { en3.index= 3}.should raise_error FiberError
  end
end
