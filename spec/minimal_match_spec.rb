require 'minimal_match'
require 'minimal_match/kernel'

describe "expression evaluation" do
  it "compile simple match expression" do
    me = m(1)
    me.to_s.should == 'm(1)'
    eval(me.to_s).inspect.should == m(1).inspect
  end

  it "compile grouped match expression" do
    me = m(1,2,3)
    me.to_s.should == 'm(1,2,3)'
    eval(me.to_s).inspect.should == m(1,2,3).inspect
  end

  it "compile nested group expression" do
    me = m(1,m(2,3))
    me.to_s.should == 'm(1,m(2,3))'
    eval(me.to_s).inspect.should == m(1,m(2,3)).inspect
  end

  describe "should compile greedy matchers" do
    it "should do one or more" do
      me = +(m(1,2))
      me.to_s.should == '+(m(1,2))'
      eval(me.to_s).inspect.should == (+(m(1,2))).inspect
    end
   
    it "should do zero or one" do
      me = ~(m(1,2))
      me.to_s.should == '~(m(1,2))'
      eval(me.to_s).inspect.should == (~(m(1,2))).inspect
    end

    it "should do zero or more" do
      # this is complicated by that the fact that the
      # * expander only works within an array
      # in practice, you always pass an array as a the 
      # match pattern, but it looks sort of weird as a test
      me = [*(m(1,2))]
      me[0].to_s.should == '*(m(1,2))'
      eval("[#{me[0].to_s}]").inspect.should == [*(m(1,2))].inspect
    end

    it "should do counted ranges" do
      me = m(1)[1..5]
      me.to_s.should == 'm(1)[1..5]'
      eval(me.to_s).inspect.should == m(1)[1..5].inspect
    end

    it "specific number shortcut" do
      me = m(1)*4
      me.to_s.should == 'm(1)[4..4]'
    end
  end

  describe "should compile non-greedy matchers" do
    it "should do one or more" do
      me = +(m(1,2)).non_greedy
      me.to_s.should == '+(m(1,2)).non_greedy'
      eval(me.to_s).inspect.should == (+(m(1,2))).non_greedy.inspect
    end

    it "should do zero or one" do
      me = ~(m(1,2)).non_greedy
      me.to_s.should == '~(m(1,2)).non_greedy'
      eval(me.to_s).inspect.should == (~(m(1,2))).non_greedy.inspect
    end

    it "should do zero or more" do
      me = [*(m(1,2)).non_greedy]
      me[0].to_s.should == '*(m(1,2)).non_greedy'
      eval("[#{me[0].to_s}]").inspect.should == [*(m(1,2)).non_greedy].inspect
    end

    it "counted ranges non-greedy" do
      me = m(1)[1..5].non_greedy
      me.to_s.should == 'm(1)[1..5].non_greedy'
      eval(me.to_s).inspect.should == m(1)[1..5].non_greedy.inspect
    end
  end
      
  it "should compile alteration" do 
    me = m(1)|m(2)
    me.to_s.should == 'm(1)|m(2)'
    eval(me.to_s).inspect.should == (m(1)|m(2)).inspect

    me = m(1)|m(2)|m(3,4,5)
    me.to_s.should == 'm(1)|m(2)|m(3,4,5)'
    eval(me.to_s).inspect.should == (m(1)|m(2)|m(3,4,5)).inspect
  end
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

  describe "groups matches" do
    it "should group matches" do
      ([1,2,3] =~ [1,m(2,3)]).should == true
    end
  end

  describe "matches anything" do
    it "simply" do
      ([1,2,3,4,5] =~ [Anything,2,3,4,5]).should == true
      ([1,2,3,4,5] =~ [Anything]).should == true
      ([1,2,3,4,5] =~ [Anything,3]).should == false
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

  it "returns index of pattern" do
    ([1,2,3,4,5].match([3]).begin).should == 2
    x = [1,2,3,4,5].match([3,4])
    x.begin.should == 2
    x.end.should == 3
    x.length.should == 2
    ([1,2,[3,4,5],6].match([[3,4]]).begin).should == 2
    ([1,2,[3,4],5,6].match([[3,4,5]])).should == false
    ([1,2,3,[4],5].match([[4]]).begin).should == 3
  end

  describe "keene star" do
    it "matches greedily with keenestar" do
      # these two match using the same NFA 
      ([1,2,3,4,5] =~ [1,*m(Anything),5]).should == true
      ([1,2,3,4,5] =~ [1,*m(Anything)]).should == true

      
      ([1,2,3,4,5] =~ [1,*m(Anything),4]).should == true
      ([1,2,3,4,5] =~ [1,*m(Anything),6]).should == false
    end

    it "matches non-greedy" do
      ([1,2,3,4,5] =~ [1,*!m(Anything),5]).should == true


    it "matches recursively with splat" do
      ([1,2,3,4,[3,4,5]] =~ [1,*m(Anything),[3,4]]).should == true
      ([1,2,[3,4],5,6,[7,8]] =~ [1,2,[3,4],*m(Anything), [7,8]]).should == true
      ([1,2,[3,4,[5,6,7,8]],9,10] =~ [1,2,[3,4,[5,6,7,8]], *m(Anything)]).should == true
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

  it "can splat a match_proc" do
    is_integer = MinimalMatch::MatchProc.new { |x| x.is_a? Fixnum }
    x = [*is_integer,'bob']
    ([1,2,3] =~ x).should == false
    ([1,2,3,'bob'] =~ x).should == true
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
    ([1,2,3,4,5,6,7] =~ [*whatev,5,MinimalMatch.ends_with(6)]).should == false 
    is_bob = lambda { |x| x == 'bob' } 
    ([1,2,[3,4]] =~ [1,2, MinimalMatch.ends_with(Array)]).should == true
    ([1,2,3,'bob'] =~ [*whatev, MinimalMatch.ends_with(is_bob)]).should == true
  end
end
   
