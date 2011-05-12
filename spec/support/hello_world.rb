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


class Dummy
  include Enumerable
  def foo
    puts "bar"
  end

  def bar
    puts "foo"
  end
end

class Dumber
  include Enumerable
  def foo
    puts "bar"
  end

  def baz
    puts "foobile"
  end
end
