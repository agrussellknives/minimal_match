require 'simplecov'
SimpleCov.start

require 'minimal_match'
require 'ripper'

class Array
  include MinimalMatch
end

describe "minmal array searching" do
  
  before :any do
    #create a big fat searchable array
    dir = File.dirname(__FILE__)
    @array = Ripper::SexpBuilder.new(File.open('#{dir}/spec_helper.rb')).parse
  end

  it "should be able to find things in that array" do
    search = @array.find [:class, [:const_ref, [:const, "Array"]]
    search.next.should == [:class, [:const_ref, [:const, "Array", 
      [7, 6]]], nil, [:bodystmt, [:stmts_add, [:stmts_new],
      [:command, [:ident, "include", [8, 2]], [:args_add_block,
      [:args_add, [:args_new], [:var_ref, [:const, "MinimalMatch", 
      [8, 10]]]], false]]], nil, nil, nil]]
  end

  it "should be able to find multiple results" do
    @array.find [:@const, ]
