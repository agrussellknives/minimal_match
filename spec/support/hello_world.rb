class Hello
  module Whatever
    def foo
      "bar"
    end
  end

  def initialize stuff
    @stuff = stuff
  end

  def stuff
    @stuff + 1
  end
end
    
