require 'spec_helper'


require 'minimal_match'
require 'minimal_match/kernel'

def pc thing
  thing.each_with_index.inject "" do |(e,i), memo|
    memo << "#{'%0d' % i} : e\n"
    memo
  end
  memo
end

describe "expression evaluation" do

  it "compile simple match expression" do
    me = m(1)
    me.to_s.should == 'm(1)'
    eval(me.to_s).inspect.should == m(1).inspect
    me.compile.should == [[:lit,1]]
  end

  it "compile grouped match expression" do
    me = m(1,2,3)
    me.to_s.should == 'm(1,2,3)'
    eval(me.to_s).inspect.should == m(1,2,3).inspect
    me.compile.should == [[:hold, 0], [:lit, 1], [:lit, 2], [:lit, 3], [:save, 0]]
  end

  it "compile nested group expression" do
    me = m(1,m(2,3))
    me.to_s.should == 'm(1,m(2,3))'
    eval(me.to_s).inspect.should == m(1,m(2,3)).inspect
    me.compile.should == [[:hold, 0], [:lit, 1], [:hold, 2], [:lit, 2], [:lit, 3], [:save, 2], [:save, 0]] 
  end

  describe "should compile greedy matchers" do
    it "should do one or more" do
      me = +(m(1,2))
      me.to_s.should == '+(m(1,2))'
      eval(me.to_s).inspect.should == (+(m(1,2))).inspect
      me.compile.should == [[:hold, 0], [:lit, 1], [:lit, 2], [:save, 0], [:split, 0, 5], [:noop]]
    end
   
    it "should do zero or one" do
      me = ~(m(1,2))
      me.to_s.should == '~(m(1,2))'
      eval(me.to_s).inspect.should == (~(m(1,2))).inspect
      me.compile.should == [[:split, 1, 5], [:hold, 0], [:lit, 1], [:lit, 2], [:save, 0], [:noop]]
    end

    it "should do zero or more" do
      # this is complicated by that the fact that the
      # * expander only works within an array
      # in practice, you always pass an array as a the 
      # match pattern, but it looks sort of weird as a test
      me = [*(m(1,2))]
      me[0].to_s.should == '*(m(1,2))'
      eval("[#{me[0].to_s}]").inspect.should == [*(m(1,2))].inspect
      me[0].compile.should == [[:split, 1, 6], [:hold, 0], [:lit, 1], [:lit, 2], [:save, 0], [:jump, 0], [:noop]]
    end

    it "should do counted ranges" do
      me = m(1)[1..3]
      me.to_s.should == 'm(1)[1..3]'
      eval(me.to_s).inspect.should == m(1)[1..3].inspect
      me.compile.should == [[:lit, 1], [:split, 3, 4], [:lit, 1], [:noop], [:split, 6, 7], [:lit, 1], [:noop], [:split, 9, 10], [:lit, 1], [:noop], [:split, 12, 13], [:lit, 1], [:noop]] 
    end

    it "specific number shortcut" do
      me = m(1)*4
      me.to_s.should == 'm(1)[4..4]'
      eval(me.to_s).inspect.should == me.inspect
      me.compile.should == [[:lit, 1], [:lit, 1], [:lit, 1], [:lit, 1]]
    end
  end

  describe "should compile non-greedy matchers" do
    it "should do one or more" do
      me = +(m(1,2)).non_greedy
      me.to_s.should == '+(m(1,2)).non_greedy'
      eval(me.to_s).inspect.should == (+(m(1,2))).non_greedy.inspect
      me.compile.should == [[:hold, 0], [:lit, 1], [:lit, 2], [:save, 0], [:split, 5, 0], [:noop]]
    end

    it "should do zero or one" do
      me = ~(m(1,2)).non_greedy
      me.to_s.should == '~(m(1,2)).non_greedy'
      eval(me.to_s).inspect.should == (~(m(1,2))).non_greedy.inspect
      me.compile.should == [[:split, 5, 1], [:hold, 0], [:lit, 1], [:lit, 2], [:save, 0], [:noop]]
    end

    it "should do zero or more" do
      me = [*(m(1,2)).non_greedy]
      me[0].to_s.should == '*(m(1,2)).non_greedy'
      eval("[#{me[0].to_s}]").inspect.should == [*(m(1,2)).non_greedy].inspect
      me[0].compile.should == [[:split, 6, 1], [:hold, 0], [:lit, 1], [:lit, 2], [:save, 0], [:jump, 0], [:noop]]
    end

    it "counted ranges non-greedy" do
      me = m(1)[1..5].non_greedy
      me.to_s.should == 'm(1)[1..5].non_greedy'
      eval(me.to_s).inspect.should == m(1)[1..5].non_greedy.inspect
      me.compile.should == [[:lit, 1], [:split, 4, 3], [:lit, 1], [:noop], [:split, 6, 7], [:lit, 1], [:noop], [:split, 10, 9], [:lit, 1], [:noop], [:split, 12, 13], [:lit, 1], [:noop]]
    end
  end
      
  it "should compile alteration" do 
    me = m(1)|m(2)
    me.to_s.should == 'm(1)|m(2)'
    eval(me.to_s).inspect.should == (m(1)|m(2)).inspect
    me.compile.should == [[:split, 1, 3], [:lit, 1], [:jump, 4], [:lit, 2], [:noop]]

    me = m(1)|m(2)|m(3,4,5)
    me.to_s.should == 'm(1)|m(2)|m(3,4,5)'
    eval(me.to_s).inspect.should == (m(1)|m(2)|m(3,4,5)).inspect
    me.compile.should == [[:split, 1, 7], [:split, 2, 4], [:lit, 1], [:jump, 5], [:lit, 2], [:noop], [:jump, 12], [:hold, 7], [:lit, 3], [:lit, 4], [:lit, 5], [:save, 7], [:noop]]
  end

  describe "should compile patterns" do
    
    it "alternation" do
      me = MinimalMatch::MatchPattern.new([m(1)|m(2)])
      me.to_s.should == "[m(1)|m(2)]"
      eval(me.to_s).inspect.should == me.inspect
    end

    it "one or more" do
      me = MinimalMatch::MatchPattern.new([+m(1),+m(2)]) 
      me.to_s.should == "[+(m(1)),+(m(2))]"
      eval(me.to_s).inspect.should == me.inspect

      #nongreedy
      me = MinimalMatch::MatchPattern.new([+!m(1),+!m(2)])
      me.to_s.should == "[+(m(1)).non_greedy,+(m(2)).non_greedy]"
      eval(me.to_s).inspect.should == me.inspect
    end

    it "zero or one" do
      me = MinimalMatch::MatchPattern.new([~m(1),~m(2)])
      me.to_s.should == "[~(m(1)),~(m(2))]"
      eval(me.to_s).inspect.should == me.inspect

      #nongreedy
      me = MinimalMatch::MatchPattern.new([~!m(1),~!m(2)])
      me.to_s.should == "[~(m(1)).non_greedy,~(m(2)).non_greedy]"
      eval(me.to_s).inspect.should == me.inspect
    end

    it "zero or more" do
      me = MinimalMatch::MatchPattern.new([*m(1),*m(2)])
      me.to_s.should == "[*(m(1)),*(m(2))]"
      eval(me.to_s).inspect.should == me.inspect

      #nongreedy
      me = MinimalMatch::MatchPattern.new([*!m(1),*!m(2)])
      me.to_s.should == "[*(m(1)).non_greedy,*(m(2)).non_greedy]"
      eval(me.to_s).inspect.should == me.inspect
    end

    it "counted ranges" do
      me = MinimalMatch::MatchPattern.new([m(1)*3,m(2)[3..5]])
      me.to_s.should == "[m(1)[3..3],m(2)[3..5]]"
      eval(me.to_s).inspect.should == me.inspect

      #nongreedy
      me = MinimalMatch::MatchPattern.new([!m(1)*3,!m(2)[3..5]])
      me.to_s.should == "[m(1)[3..3].non_greedy,m(2)[3..5].non_greedy]"
      eval(me.to_s).inspect.should == me.inspect
    end
  end
end

