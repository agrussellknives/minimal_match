#require 'spec_helper'

require 'minimal_match'
require 'minimal_match/kernel'


describe "simple array matching" do

  describe "groups matches" do
    it "should group matches" do
      ([1,2,3] =~ [1,m(2,3)]).should == true
    end

    it "can nest matches to create complicated patterns" do
      ([2,2,2,2,2,2] =~ [m(m(2)*3)*2]).should == true
      ([2,2,2,2,2] =~ [m(m(2)*3)*2]).should == false # only one group of three and a group of two 
    end

    it "can deal with epsilon transitions" do
      pattern = MinimalMatch::MatchPattern.new([!m(2)[2..4],End])
      pattern.has_epsilon?.should == true
      pattern.length.nan?.should == true #infinity!
      ([2,2,2,2] =~ pattern).should == true
      ([2,2,2,2,2] =~ pattern).should == false
      ([2] =~ pattern).should == false
      ([2,2,2] =~ pattern).should == true
    end
  end

  describe "matches anything" do
    it "simply" do
      ([1,2,3,4,5] =~ [Anything,2,3,4,5]).should == true
      ([1,2,3,4,5] =~ [Anything]).should == true
      ([1,2,3,4,5] =~ [Anything,3]).should == true 
    end
    
    it "matches greedily with kleenestar" do
      # these two match using the same NFA 
      ([1,2,3,4,5] =~ [1,*m(Anything),5]).should == true
      ([1,2,3,4,5] =~ [1,*m(Anything),5]).should == true
      ([1,2,3,4,5] =~ [1,*m(Anything)]).should == true
      ([1,2,3,4,5] =~ [1,*m(Anything),6]).should == false
    end

    it "matches non-greedy" do
      ([1,2,3,4,5] =~ [1,*!m(Anything),5]).should == true
    end

    it "matches recursively with splat" do
      ([1,2,3,4,[3,4,5]] =~ [1,*m(Anything),[3,4]]).should == true
      ([1,2,[3,4],5,6,[7,8]] =~ [1,2,[3,4],*m(Anything),[7,8]]).should == true
      ([1,2,[3,4,[5,6,7,8]],9,10] =~ [1,2,[3,4,[5,6,7,8]], *m(Anything)]).should == true
    end

    it "matches an specifc number of MinimalMatch.anythings" do
      
      ([1,2,3,4,5] =~ [1,m(Anything) * 3, 5]).should == true
      
      mult_test = lambda do |f|
        [1,2,3] =~ [1,m(Anything)*f]
      end
      lambda { mult_test.call('berney') }.should raise_error ArgumentError
      mult_test.call(2).should == true
    end  

    it "matches a specific number of anythings nestedly" do
      ([1,2,[3,4,5,6]] =~ [1,[3,m(Anything) * 3]]).should ==  false
      ([1,2,3,4,[5,6,7,8]] =~ [1, m(Anything) * 3, [5, m(Anything) * 3]]).should == true
      ([1,2,[3,4,5]] =~ [1,m(Anything) * 2,[3,4]]).should == false

    end

    it "recursively" do
      ([1,[2,3,[4,5,6]]] =~ [1,[2,Anything,[4,Anything,6]]]).should == true
      ([1,2,[3,4,5]] =~ [1,Anything,[3,4]]).should == true
    end
  end

  it " matches things that might not be there" do
    ([1,2,3,4,5] =~ [1,2,~m(3),4,5]).should == true
    ([1,2,4,5] =~ [1,2,~m(3),4,5]).should == true
    ([1,[2,[4]]] =~ [1,[2,~m(3),[4]]]).should == true
  end

  
  it "specific number counts towards too long" do
    ([1,2,3] =~ [1,m(Anything)*3]).should == false
    ([1,2,3,[4,5]] =~ [1,m(Anything)*2,[4,5]]).should == true
  end

  it "can match anything matching a list of items" do
    ([1,2,3,4] =~ [1,m([2,'a',:sym]),3]).should == true
    ([1,'a',3,4] =~ [1,m([2,'a',:sym]),3]).should == true
    ([1,:sym,3,4] =~ [1,m([2,'a',:sym]),3]).should == true
    ([1,'b',3,4] =~ [1,m([2,'a',:sym]),3]).should == false 
  end

  it "can save matches for later" do
    x = [1,m([2,3,4]),5]
    ([1,2,3,4,5] =~ x).should == false
    ([1,2,5] =~ x).should == true
  end

  it "does something useful with inspect" do
    x = [1,m([2,3,4]),5]
    x.inspect.should == "[1, <MinimalMatch::AnyOf:[2, 3, 4] : MatchProxy>, 5]"
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
    is_integer = lambda { |x| x.is_a? Fixnum }.to_m #proxy a proc
    x = [ is_integer * 3]
    ([1,2,3] =~ x).should == true
    ([8,65,3] =~ x).should == true
    (['no',2,3] =~ x).should == false
  end

  it "can splat a match_proc" do
    is_integer = m { |x| x.is_a? Fixnum }
    x = [*is_integer,'bob']
    ([1,2,3] =~ x).should == false
    ([1,2,3,'bob'] =~ x).should == true

  end

  it "can match the beginning of Arrays" do
    ([1,2,3] =~ [Begin,1,2,3]).should == true 
    ([1,2,3] =~ [Begin,2,3]).should == false
    ([1,2,3,4,5] =~ [3,4,Begin,1,2,3]).should == true

    ([1,2,3,4,5] =~ [4,5]).should == true #demonstration purposes only
    ([1,2,3,4,5] =~ [Begin,1,2]).should == true #matches at end
    ([1,2,3,4,5] =~ [Begin,1,2,*m(Anything)]).should == true
    ([1,2,3,3,4,5,6,7] =~ [Begin,2,3,*m(Anything)]).should == false
    ([[1,2,3],4,5] =~ [Begin,Array,4,5]).should == true
    (['bob',2,3,4] =~ [Begin, m { |x| x == 'bob'}])

  end

  it "can use anything which responds to ===" do
    ([1,"bob",[1,2]] =~ [Fixnum, String, Array]).should == true
  end

  it "can match the end of an Array" do
    ([1,2,3,4,5] =~ [1,2,3,End]).should == false
    ([1,2,3] =~ [1,2,3,End]).should == true
    ([1,2,3] =~ [1,2,3,End,4,5,6]).should == true
    # find something only at the end 
    ([1,2,3,4,5,6] =~ [4,5]).should == true # just for demonstrating
    ([1,2,3,4,5,6] =~ [4,5,6,End]).should == true 
    ([1,2,3,4,5,6,7] =~ [2,*m(Anything),5,6,End]).should == false 
    ([1,2,[3,4]] =~ [1,2,Array,End]).should == true
    ([1,2,3,'bob'] =~ [m {|x| x == 'bob' },End]).should == true
  end

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
      # it WON'T match this because it's looking for [3,4] in the origional array
      ([1,2,[3,4],5] =~ [3,4]).should == false
      # in order to match it you have to give the correct nesting level
      ([1,2,[3,4],5] =~ [[3,4]]).should == true
      
      ([1,[2,3,[4,5]]] =~ [1,[2,3,[4,5]]]).should == true
      ([1,[2,[4]]] =~ [1,[2,[4]]]).should == true
      
      # match pattern is too specific (ie, it has a 3 follow array 2)
      ([1,[2,[4]]] =~ [1,[2,3,[4]]]).should == false 
      # in order to match both see the maybe thing
      
      #because position two of the array is not [3,4]
      ([1,2,[3,4,5]] =~ [1,[3,4]]).should == false
    end

    it "matches simple proxies" do
      ([1,2,3] =~ [m(1), m(2), m(3)])
      (['a','b','c'] =~ [m('a'),m('b'), m('c')]).should == true
      ([{:foo => :bar},{:baz => :bab}] =~ [m({:foo => :bar}),m({:baz => :bab})]).should == true
      ([1,2,3] =~ [m(3),m(2),m(1)]).should == false
    end
  end
end
   
