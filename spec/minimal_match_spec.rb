require 'simplecov'
SimpleCov.start

require 'minimal_match'


class Array
  include MinimalMatch
end


describe "simple array matching" do

  it "should do obvious things" do
    ([1,2,3] =~ [1,2,3]).should == true
    (['a','b','c'] =~ ['a','b','c']).should == true
    ([{:foo => :bar},{:baz => :bab}] =~ [{:foo => :bar},{:baz => :bab}]).should == true
  end

  it "is a non greedy matcher" do
    ([1,2,3,4,5] =~ [1,2,3]).should == true
    ([1,2,3] =~ [1,2,3,4,5]).should == false
  end

  it "matches recursively" do
    ([1,[2,3,[4,5]]] =~ [1,[2,3,[4,5]]]).should == true
    ([1,[2,[4]]] =~ [1,[2,[4]]]).should == true
    # match pattern is too specific
    ([1,[2,[4]]] =~ [1,[2,3,[4]]]).should == false 

    #because position two of the array is not [3,4]
    ([1,2,[3,4,5]] =~ [1,[3,4]]).should == false
  end

  it "matches with Array::Anything" do
    ([1,2,3,4,5] =~ [Array::Anything,2,3,4,5]).should == true
    ([1,2,3,4,5] =~ [Array::Anything]).should == true
    ([1,2,3,4,5] =~ [Array::Anything,3]).should == false
  end

  it "maches with Array::Anything recursively" do
    ([1,[2,3,[4,5,6]]] =~ [1,[2,Array::Anything,[4,Array::Anything,6]]]).should == true
    ([1,2,[3,4,5]] =~ [1,Array::Anything,[3,4]]).should == true
    
  end

  it "matches greedily with splat" do
    ([1,2,3,4,5] =~ [1,*Array::Anything,5]).should == true
    ([1,2,3,4,5] =~ [1,*Array::Anything]).should == true
    # ends with something not in the array
    ([1,2,3,4,5] =~ [1,*Array::Anything,6]).should == false
  end

  it "matches recursively with splat" do
    ([1,2,3,4,[3,4,5]] =~ [1,*Array::Anything,[3,4]]).should == true
    ([1,2,[3,4,[5,6,7,8]],9,10] =~ [1,2,[3,4,[5,6,7,8]], *Array::Anything]).should == true
  end

  it "matches multiple splats" do
    ([1,2,3,4,5,6,7,8] =~ [1,*Array::Anything,5,*Array::Anything,8]).should == true
    ([1,2,[3,4,5],[6,7,8,9]] =~ [1,2,[3,Array::Anything,5],[6,*Array::Anything,9]]).should == true
    ([1,2,[3,4,4.5,4.75,5],[6,8,8,9]] =~ [1,2,[3,*Array::Anything,5],[6,*Array::Anything,9]]).should == true
  end

  it "matches an specifc number of Array::Anythings" do
    
    describe "the array flattener" do
      it "flattens arrays when they are found" do
        x = [1,Array::Anything * 3, 5]
        x = Array::Anything.flatten_match_array x
        x.should == [1, MinimalMatch::Anything, MinimalMatch::Anything, MinimalMatch::Anything, 5]
      end

      it "doesn't flatten recursively" do
        x = [1,[2, Array::Anything * 3]]
        x = Array::Anything.flatten_match_array x
        x.should == [1,[2, Array::Anything * 3]]
      end

      it "doesn't flatting arrays with anything other than specifics in them" do
        x = [1,[2,3,[4,5,6]]]
        x = Array::Anything.flatten_match_array x
        x.should == [1,[2,3,[4,5,6]]]
      end

      it "can flatten more than once" do
        x = [1, Array::Anything * 2, 4, Array::Anything * 3]
        x = Array::Anything.flatten_match_array x
        x.should == [1, MinimalMatch::Anything, MinimalMatch::Anything, 4, 
          MinimalMatch::Anything, MinimalMatch::Anything, MinimalMatch::Anything]
      end
    end

    ([1,2,3,4,5] =~ [1, Array::Anything * 3, 5]).should == true
    ([1,2,3,4,5] =~ [1, 3 * Array::Anything, 5]).should == true
    
    mult_test = lambda do |f|
      ([1,2,3] =~ [1,Array::Anything * f])
    end
    mult_test.call('berney').should_raise ArgumentError
    mult_test.call(2).should == true
  end  

  it "matches a specific number of anythings nestedly" do
    ([1,2,[3,4,5,6]] =~ [1,[3,Array::Anything * 3]]).should ==  false
    ([1,2,3,4,[5,6,7,8]] =~ [1, Array::Anything * 3, [5, Array::Anything * 3]]).should == true
    ([1,2,[3,4,5]] =~ [1,Array::Anything * 2,[3,4]]).should == false

  end

  it "specific number counts towards too long" do
    ([1,2,3] =~ [1,Array::Anything*3]).should == false
    ([1,2,3,[4,5]] =~ [1,Array::Anything * 2,[4,5]]).should == true
  end

  it "can match anything matching a list of items" do
    ([1,2,3,4] =~ [1,Array::AnyOf[2,'a',:sym],3]).should == true
    ([1,'a',3,4] =~ [1,Array::AnyOf[2,'a',:sym],3]).should == true
    ([1,:sym,3,4] =~ [1,Array::AnyOf[2,'a',:sym],3]).should == true
    ([1,'b',3,4] =~ [1,Array::AnyOf[2,'a',:sym],3]).should == false 
  end

  it "can save matches for later" do
    x = [1,Array::AnyOf[2,3,4],5]
    x.inspect.should == "[1, MinimalMatch::AnyOf:[2, 3, 4], 5]"
    ([1,2,3,4,5] =~ x).should == false
    ([1,2,5] =~ x).should == true
  end
end
   
