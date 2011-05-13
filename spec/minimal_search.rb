$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'minimal_match'
require 'ripper'

class Array
  include MinimalMatch::MinimalSearchMixin
end

describe "minmal array searching" do
  
  before :all do
    #create a big fat searchable array
    dir = File.dirname(__FILE__)
    @array = Ripper::SexpBuilder.new(File.open("#{dir}/spec_helper.rb")).parse
  end

  it "should be able to find things in that array" do
    search = @array.search [:class, [:const_ref, [:@const, "Array"]]]
  end

  it "should be able to find multiple results" do
    search = @array.search [:@const, "Enumerable"]
    search.to_a.length.should == 2
  end

  it "should be able to chains search results" do
    #this is the way you should actually use the thing - let's find every
    #class which defines foo for instance.
    #note that this returns all the results - not just the first one.
    # does a breadth first transversal, so this a good way of finding
    # things
    res = @array.search([:class]).search([:def, [:@ident, "foo"]]).to_a
    res.length.should == 2
    res[0].should == res[1]
  end

  it "can do explicit depth first results" do
    res = @array.search([:class]).each_with_object([]) do |o, memo|
      m = o.search([:def,[:@ident, "foo"]]).to_a
      memo << m if m.length > 0
    end
    res.length.should == 2
    res[0].should == res[1]
  end

end
