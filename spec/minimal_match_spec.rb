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
      pattern = MinimalMatch::MatchPattern.new([!m(2)[2..4]])
      pattern.has_epsilon?.should == true
      pattern.length.nan?.should == true #infinity!
      ([2,2,2,2] =~ pattern).should == true
      ([2,2,2,2,2] =~ pattern).should == true 
      ([2] =~ pattern).should == false
      ([2,2,2] =~ pattern).should == true
    end

    it "groups multiple epsilons correctly" do
      ([2,2,2,2] =~ m(m(2)[2..4]).bind).should == true
      MinimalMatch.last_match.captures.should == [[2,2,2,2],[2,2,2,2]]
      ([2,2,2,2] =~ m(!m(2)[2..4]).bind).should == true
      MinimalMatch.last_match.captures.should == [[2,2,2,2],[2,2]]
    end

    it "patterns can be straight groups if you like" do
      [2,2,2,2] =~ m(2).bind[2..4]
      lm = MinimalMatch.last_match
      [2,2,2,2] =~ m(2).bind[2..4]
      lm.should == MinimalMatch.last_match
      ([1,2,3,4] =~ [1,2,3,4]).should == true
      fc = MinimalMatch.last_match.captures[0]
      ([1,2,3,4] =~ m(1,2,3,4)).should == true
      fc.should == MinimalMatch.last_match.captures[0]
    end
  end

  describe "can manipulate patterns" do
    it "can change nested pattern" do
      pattern = MinimalMatch::MatchPattern.new(m(m(2)[2..4]).bind)
      ([2,2,2,2] =~ pattern).should == true
      lm = MinimalMatch.last_match
      lm.captures.should == [[2,2,2,2],[2,2,2,2]]
      pattern[0][0] = pattern[0][0].non_greedy
      pattern.compile
      ([2,2,2,2] =~ pattern).should == true
      MinimalMatch.last_match.captures.should == [[2,2,2,2],[2,2]]
    end

    it "can change first level patterns" do
      pattern = MinimalMatch::MatchPattern.new([1,2,3,4])
      arr = [1,2,3,4]
      (arr =~ pattern).should == true
      pattern[0] = 2
      (arr =~ pattern).should == false
      arr[0] = 2
      (arr =~ pattern).should == true
    end
 
  end

  it "catches pathological patterns in the act" do
    evil_pattern = [m(+m('x'),+m('x')),+m('y')]
    innocent_input = ["x"] * 20
    lambda do 
      innocent_input =~ evil_pattern
    end.should raise_error MinimalMatch::MatchMachine::PathologicalPatternError
  end

  describe "introspection" do
    it "pattern can pretty print" do
      pat = MinimalMatch::MatchPattern.new([1,2,3,4])
      # includes all the accoutrement
      pat.pp.should == <<-PP
000 : [:hold, 0]
001 : [:split, 4, 2]
002 : [:lit, Anything]
003 : [:jump, 1]
004 : [:noop]
005 : [:lit, 1]
006 : [:lit, 2]
007 : [:lit, 3]
008 : [:lit, 4]
009 : [:split, 10, 12]
010 : [:lit, Anything]
011 : [:jump, 9]
012 : [:noop]
013 : [:save, 0]
014 : [:match]
      PP
    end

    it "minimalmatch heirarchy objects have some instrospection" do
      # you might need this if you wind up writing additional operators
      obj = m([1,2,3])
      (obj.kind_of? MinimalMatch::MinimalMatchObject).should == true
      (is_proxy? obj).should == true
      (is_match_op? obj).should == true
      # yep, anyof is a literal, because just doing "include? on the 
      # array is about 1,000 times faster than any vm stuff I'm 
      # going to write
      debugger
      obj.compile.should == [[:lit, MinimalMatch::AnyOf[1,2,3]]]
    end

    it "should be able to proxy a class object" do
      obj = m(String)
      (obj === "hello").should == true
    end

    it "can get objects out of the proxy" do
      p2 = m(2)
      x = (p2 + 4)
      x.should == 6
      p2.to_obj.should == 2
      am = [1,2,3,4].to_m
      o = am.to_obj #dups
      o << 5 
      am.last.should == 4
      o = am.comp_obj #does not
      o << 6
      am.last.should == 6
    end
      
      it "proxying an proxy does not double proxy" do
        me = m(1)
        me.class.should == Fixnum
        me2 = m(me)
        me.class.should == Fixnum
        me.to_obj.should == me2.to_obj
      end

      it "handles nil / false proxies and results of proxies" do
        me = m(nil)
        me.nil?.should == true
        (me and 1).should == 1 #sorry.
        (me.to_obj and 1).should == nil
        m2 = m(3)
        res = (2 <=> m2)
        res.should == -1
        (is_proxy? res).should == true
        res = (2 < m2)
        res.should == false
        (is_proxy? res).should == false
      end

      it "properly coerces proxies for commutative operators" do
        # are there more commutative operators?
        me = m(5)
        x = (me + 5)
        (x).should == (5 + me)
        (is_proxy? x).should be true
        x.should == 10
        y = (me * 5)
        y.should != 25 #because * is overridden to mean "multiply"
        (3 - me).should == -2
        (me - 3).should == 2
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

  describe "it matches greedy and non_greedy repitions" do
    
    it "can change between greedy and non_greedy" do
      mp_g = m(2)[2..4] 
      [2,2,2,2] =~ m(mp_g.non_greedy).bind
      MinimalMatch.last_match.captures[1].should == [2,2]
      mp_g = !m(2)[2..4] #nongreedy
      [2,2,2,2] =~ m(mp_g.greedy).bind
      MinimalMatch.last_match.captures[1].should == [2,2,2,2]
    end

    it "remembers the setting of the matchproxy" do
      mp = m(2)
      mp[2..4].to_s.should == "m(2)[2..4]"
      mp.non_greedy
      mp[2..4].to_s.should == "m(2)[2..4].non_greedy"
    end

    it "knows how to reverse itself" do
      # use the named methods to make call order obvious
      mp = m(2)
      mp.kleene.to_s.should == "*(m(2))"
      mp.kleene.non_greedy.to_s.should == "*(m(2)).non_greedy"
      mp.kleene.non_greedy.greedy.to_s.should == "*(m(2))"
      mp.quest.to_s.should == "~(m(2))"
      mp.quest.non_greedy.to_s.should == "~(m(2)).non_greedy" 
      mp.quest.non_greedy.greedy.to_s.should == "~(m(2))"
      mp.plus.to_s.should == "+(m(2))"
      mp.plus.non_greedy.to_s.should == "+(m(2)).non_greedy"
      mp.plus.non_greedy.greedy.to_s.should == "+(m(2))"
    end

    it "switches back and forth with the ! operator" do
      mp = m(2)
      mp.kleene.to_s.should == "*(m(2))"
      !mp
      mp.greedy?.should == false
      mp.kleene.to_s.should == "*(m(2)).non_greedy"
      !mp
      mp.greedy?.should == true
      mp.kleene.to_s.should == "*(m(2))"
    end

    it "coerces between ranges and ints" do
      mp = m(5).times 5
      arr = [5] * 4
      (arr =~ mp ).should == false
      arr << 5
      (arr =~ mp).should == true
      arr << 5
      (arr =~ mp).should == true #cause 5 < 6
      mp = m(5).times 3..7
      (arr =~ mp).should == true
      mp = m(5) * 3
      (arr =~ mp).should == true
      mp = m(5) * (7..10)
      (arr =~ mp).should == false
      lambda { m(5) * 'frank' }.should raise_error ArgumentError
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
    x.inspect.should == "[1, <MinimalMatch::AnyOf[2, 3, 4] : MatchProxy>, 5]"
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

  it "can stop search as soon as the pattern matches" do
    #by default, there is an implicit kleene star at the end of the 
    #pattern. Appending a Stop literal to the end of the patter
    #will mean that the pattern will not capture after that point.
    ([1,2,3,4] =~ [1,2]).should == true
    MinimalMatch.last_match.captures[0] = [1,2,3,4]
    ([1,2,3,4] =~ [1,2,Stop]).should == true
    MinimalMatch.last_match.captures[0] = [1,2]
  end

  it "can use anything which responds to ===" do
    ([1,"bob",[1,2]] =~ [Fixnum, String, Array]).should == true
  end

  it "can proxy anything respoding to === correctly" do
    (["bob","frank","bill"] =~ m(String) * 3).should == true
    (["MacArthur","MacLeod","MacLachlan","MacShawimamahimalingleberryknockadoodle"] =~ [m(/Mac[A-Z][a-z]+/).bind * 3, Stop]).should == true
    MinimalMatch.last_match.captures[0].should == ["MacArthur","MacLeod","MacLachlan"]
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
