require 'minimal_match'

class Array
  include MinimalMatch
end


describe "simple array matching" do

  describe "dead simple stuff" do
    it "should do obvious things" do
      ([1,2,3] =~ [1,2,3]).should == true
      (['a','b','c'] =~ ['a','b','c']).should == true
      ([{:foo => :bar},{:baz => :bab}] =~ [{:foo => :bar},{:baz => :bab}]).should == true
      ([1,2,3] =~ [3,2,1]).should == false
    end

    it "is a non greedy matcher" do
      ([1,2,3,4,5] =~ [1,2,3]).should == true
      ([1,2,3] =~ [1,2,3,4,5]).should == false
    end

    it "matches in the middle" do
      ([1,2,3,4,5] =~ [3,4]).should == true
      ([1,2,3,4,5] =~ [3,5]).should == false
      ([1,2,3,4,5] =~ [4,5,6]).should == false
    end

    it "matches recursively" do
      ([1,[2,3,[4,5]]] =~ [1,[2,3,[4,5]]]).should == true
      ([1,[2,[4]]] =~ [1,[2,[4]]]).should == true
      # match pattern is too specific
      ([1,[2,[4]]] =~ [1,[2,3,[4]]]).should == false 

      #because position two of the array is not [3,4]
      ([1,2,[3,4,5]] =~ [1,[3,4]]).should == false
    end
  end

  describe "matches anything" do
    it "simply" do
      ([1,2,3,4,5] =~ [MinimalMatch.anything,2,3,4,5]).should == true
      ([1,2,3,4,5] =~ [MinimalMatch.anything]).should == true
      ([1,2,3,4,5] =~ [MinimalMatch.anything,3]).should == false
    end

    it "recursively" do
      #([1,[2,3,[4,5,6]]] =~ [1,[2,MinimalMatch.anything,[4,MinimalMatch.anything,6]]]).should == true
      ([1,2,[3,4,5]] =~ [1,MinimalMatch.anything,[3,4]]).should == true
    end
  end

  #it "returns index of pattern" do
    #([1,2,3,4,5].match_index(3)).should == 2
    #([1,2,[3,4],5].match_index([3,4])).should == 2
    #([1,2,[3,4,5],6].match_index([3,4])).should == 2
    #([1,2,[3,4],5,6].match_index([3,4,5])).should == nil
    #([1,2,[3,[4,5]]].match_index([4,5])).should == nil
    #([1,2,3,[4],5]).match_index([4]).should == 3
    #([1,2,3,[4],5]).match_index(4).should == nil
  #end

  describe "splat matching" do
    it "matches greedily with splat" do
      ([1,2,3,4,5] =~ [1,*MinimalMatch.anything,5]).should == true
      ([1,2,3,4,5] =~ [1,*MinimalMatch.anything]).should == true
      # ends with something not in the array
      ([1,2,3,4,5] =~ [1,*MinimalMatch.anything,6]).should == false
    end

    it "matches things at the end" do
      ([1,2,3,4,5] =~ [*MinimalMatch.anything, 5]).should == true
      ([1,2,3,4,5,6] =~ [*MinimalMatch.anything, 5,6]).should == true
      ([1,2,3,4,5,6,7,8] =~ [*MinimalMatch.anything,5,6]).should == true
      ([1,2,3,4,5,6] =~ [*MinimalMatch.anything, 5]).should == true
    end

    it "matches recursively with splat" do
      ([1,2,3,4,[3,4,5]] =~ [1,*MinimalMatch.anything,[3,4]]).should == true
      ([1,2,[3,4],5,6,[7,8]] =~ [1,2,[3,4],*MinimalMatch.anything, [7,8]]).should == true
      ([1,2,[3,4,[5,6,7,8]],9,10] =~ [1,2,[3,4,[5,6,7,8]], *MinimalMatch.anything]).should == true
    end

    it "matches multiple splats" do
      ([1,2,3,4,5,6,7,8] =~ [1,*MinimalMatch.anything,5,*MinimalMatch.anything,8]).should == true
      ([1,2,[3,4,5],[6,7,8,9]] =~ [1,2,[3,MinimalMatch.anything,5],[6,*MinimalMatch.anything,9]]).should == true
      ([1,2,[3,4,4.5,4.75,5],[6,8,8,9]] =~ [1,2,[3,*MinimalMatch.anything,5],[6,*MinimalMatch.anything,9]]).should == true
    end
  end

  it "matches an specifc number of MinimalMatch.anythings" do
    
    describe "the array flattener" do
      it "flattens arrays when they are found" do
        x = [1,MinimalMatch.anything * 3, 5]
        x = MinimalMatch.flatten_match_array x
        z = MinimalMatch.anything # save me some typing
        x.should == [1, z, z, z, 5]
      end

      it "doesn't flatten recursively" do
        x = [1,[2, MinimalMatch.anything * 3]]
        x = MinimalMatch.flatten_match_array x
        x.should == [1,[2, MinimalMatch.anything * 3]]
      end

      it "doesn't flatting arrays with anything other than specifics in them" do
        x = [1,[2,3,[4,5,6]]]
        x = MinimalMatch.flatten_match_array x
        x.should == [1,[2,3,[4,5,6]]]
      end

      it "can flatten more than once" do
        x = [1, MinimalMatch.anything * 2, 4, MinimalMatch.anything * 3]
        x = MinimalMatch.flatten_match_array x
        z = MinimalMatch.anything
        x.should == [1, z, z, 4, z, z, z]
      end
    end

    ([1,2,3,4,5] =~ [1, MinimalMatch.anything * 3, 5]).should == true
    ([1,2,3,4,5] =~ [1, 3 * MinimalMatch.anything, 5]).should == true
    
    mult_test = lambda do |f|
      ([1,2,3] =~ [1,MinimalMatch.anything * f])
    end
    lambda { mult_test.call('berney') }.should raise_error ArgumentError
    mult_test.call(2).should == true
  end  

  it "matches a specific number of anythings nestedly" do
    ([1,2,[3,4,5,6]] =~ [1,[3,MinimalMatch.anything * 3]]).should ==  false
    ([1,2,3,4,[5,6,7,8]] =~ [1, MinimalMatch.anything * 3, [5, MinimalMatch.anything * 3]]).should == true
    ([1,2,[3,4,5]] =~ [1,MinimalMatch.anything * 2,[3,4]]).should == false

  end

  it "specific number counts towards too long" do
    ([1,2,3] =~ [1,MinimalMatch.anything*3]).should == false
    ([1,2,3,[4,5]] =~ [1,MinimalMatch.anything * 2,[4,5]]).should == true
  end

  it "can match anything matching a list of items" do
    ([1,2,3,4] =~ [1,Array::AnyOf[2,'a',:sym],3]).should == true
    ([1,'a',3,4] =~ [1,Array::AnyOf[2,'a',:sym],3]).should == true
    ([1,:sym,3,4] =~ [1,Array::AnyOf[2,'a',:sym],3]).should == true
    ([1,'b',3,4] =~ [1,Array::AnyOf[2,'a',:sym],3]).should == false 
  end

  it "can save matches for later" do
    x = [1,Array::AnyOf[2,3,4],5]
    ([1,2,3,4,5] =~ x).should == false
    ([1,2,5] =~ x).should == true
  end

  it "does something useful with inspect" do
    x = [1,Array::AnyOf[2,3,4],5]
    x.inspect.should == "[1, MinimalMatch::AnyOf:[2, 3, 4], 5]"
  end 

  it "can use arbitrary procs for matchin the items" do
    is_integer = lambda { |x| x.is_a? Fixnum }
    is_string = lambda { |x| x.is_a? String }
    x = [1,is_integer, is_string, 4]
    ([1,2,"hi",4] =~ x).should == true
    ([1,3,"bob",4] =~ x).should == true
    ([1,"bob",3,4] =~ x).should == false
    ([1,2,3,4] =~ x).should == false 
  end

  it "can define those lambda in place like a rockstar" do
    x = [1,2,3,->(y){ y > 4 and y < 8}]
    ([1,2,3,4] =~ x).should == false
    ([1,2,3,6] =~ x).should == true
    ([1,2,3,7] =~ x).should == true
    ([1,2,3,15] =~ x).should == false
  end

  it "can do explicit number matching of things on the match_proc" do
    is_integer = MinimalMatch::MatchProc.new { |x| x.is_a? Fixnum }
    x = [ is_integer * 3]
    ([1,2,3] =~ x).should == true
    ([8,65,3] =~ x).should == true
    (['no',2,3] =~ x).should == false
  end

  it "can match the beginning of Arrays" do
    ([1,2,3] =~ [MinimalMatch.begins_with(1),2,3]).should == true 
    ([1,2,3] =~ [MinimalMatch.begins_with(2),3]).should == false
    ([1,2,3,4,5] =~ [3,4,MinimalMatch.begins_with(1),2,3]).should == true
  end

  it "can use anything which responds to ===" do
    ([1,"bob",[1,2]] =~ [Fixnum, String, Array]).should == true
  end

  it "can match the end of an Array" do
    whatev = MinimalMatch.anything
    ([1,2,3,4,5] =~ [1,2,MinimalMatch.ends_with(3)]).should == false
    ([1,2,3] =~ [1,2,MinimalMatch.ends_with(3)]).should == true
    # find something only at the end 
    ([1,2,3,4,5,6] =~ [*whatev, 4,5]).should == true # just for demonstrating
    ([1,2,3,4,5,6] =~ [*whatev, 4,5, MinimalMatch.ends_with(6)]).should == true 
    debugger
    ([1,2,3,4,5,6,7] =~ [*whatev,5,MinimalMatch.ends_with(6)]).should == false 
    is_bob = lambda { |x| x == 'bob' } 
    ([1,2,[3,4,[5,6]]] =~ [1,2,is_array, MinimalMatch.ends_with(Array)]).should == true
    ([1,2,3,'bob'] =~ [*whatev, MinimalMatch.ends_with(is_bob)]).should == true
  end
end
   
