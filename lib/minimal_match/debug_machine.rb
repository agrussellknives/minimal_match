require 'tempfile'

# it is so tempting to make this into a whole little gem
module TermHelper
  class CommandCache
    remove_const :COMMANDS rescue nil
    # assemble format strings for movement commands
    movmts = Hash[[:hpa,:vpa,:cup,:home,:setaf].zip(
      [`tput hpa`, `tput vpa`, `tput cup`,`tput home`].collect do |fmt|
      fmt.split(/(%[pPg][\d\w])|(%.)/).each_with_object '' do |i,m|
        if i == '%d'
          m << '%d'
        elsif i[0] != '%'
          m << i
        end
      end
    end)]
    
    setaf = `tput setaf`.split(/(%.*?(?=%)|;)/)
    setaf = "#{setaf[0]}%s#{setaf[-1]}"
      
    COMMANDS = {
    save: `tput sc`,
    restore: `tput rc`,
    reset: `tput sgr0`,
    smacs: `tput smacs`,
    rmacs: `tput rmacs`,
    left: `tput cub1`,
    right: `tput cuf1`,
    up: `tput cuu1`,
    down: `tput cud1`,
    test: 'test',
    setaf: lambda do |color|
      str = ""
      if color < 8
        str = "3#{color}"
      elsif color < 16
        str = "9#{color-8}"
      elsif
        str = "38;5;#{color}"
      end
      setaf % str 
    end,
    mrcup: lambda do |row,col|
      hdir = col > 0 ? :right : :left
      vdir = row > 0 ? :down : :up 
      [[vdir,row],[hdir,col]].inject '' do |memo, dir|
        memo << (COMMANDS[dir[0]] * dir[1].abs)
      end
    end,
    moveto: lambda do |*args|
      # pass it either a [row,col] array or a row:x, col:x opts hash
      row,col = *({ :row => nil, :col => nil}.merge(args.first).values rescue args)
      cmd = (col and row) ? :cup : (col ? :hpa : (row ? :vpa : :home))
      movmts[cmd] % ([row, col].compact)
    end
    }
    COMMANDS.each_pair do |meth,b|
      c = b.is_a?(Proc) ? b : lambda { b }
      define_method meth, &c
    end
  end

  attr_reader :cache

  # abstractions around common escape sequences or construction
  def output string = nil 
    to_stdout = true if string
    string = "" unless string.respond_to? :<<
    yield(string) if block_given? # modifiy str in place
    if to_stdout 
      $stdout << string
    end
    string
  end

  def current_position
    #taking bids for a better implementation of this
    temp_file ||= @temp_file
    temp_file ||= Tempfile.new()
    system("stty -echo; tput u7; read -d R x; stty echo; echo ${x#??} > #{temp_file.path}")
    temp_file.gets.chomp.split(';').map(&:to_i)
  end

  def color color
    output do |str|
      str << c.setaf(color)
      str << yield
      str << c.reset
    end
  end

  def there_and_back
    raise "nested there_and_back" if @within
    @within = true
    string = output do |str|
      str << c.save 
      yield(str)
      str << c.restore
    end
    string
  ensure
    @within = false
  end

  def smacs
    output do |str|
      str << c.smacs 
      str << yield
      str << c.rmacs 
    end
  end

  def macro name, arr = nil
    string = ""
    if (block_given? and arr) or (not block_given? and not arr)
      raise ArgumentError "Array of commands or a block required."
    elsif block_given?
      str = ""
      string = yield str
    elsif arr
      string = arr.inject "" do |c| 
        self.__send__ *c
      end
    end
    @cache.define_singleton_method(name) { string }
  end

  def window row,col, width, height, opts = {}
    opts = {:color => false, :noblank => false}.merge(opts)
    str = there_and_back do |str|
      str << c.setaf(opts[:color]) if opts[:color]
      str << c.moveto(row,col)
      str << smacs { 'm'+('q' * width)+'j' }
      str << c.mrcup(0, -(width + 2))
      (height-2).times do
        str << c.mrcup(-1,0)
        str << smacs { 'x' }
        if opts[:noblank]
          str << c.mrcup(0,width)
        else
          str << ' ' * width
        end
        str << smacs { 'x' }
        str << c.mrcup(0,-(width + 2))
      end
      str << smacs { 'l' + ('q' * width) + 'k'}
      str << c.reset
      if block_given?
        str << c.mrcup(1,0)
        string = (yield).scan(/.{0,#{width}}/)
        string = string.length > rows ? string[0..rows] : string
        string.each do |l|
          str << c.mrcup(0,col)
          str << l + "\n"
        end
      end
    end
  end
  
  def c
    @cache
  end

  def _cache
    @cache = CommandCache.new
  end
  private :_cache

end


module MinimalMatch
  class DebugMachine
    include TermHelper
    include ObjectSpace

    attr_reader :home
    attr_accessor:parent, :current_inst, :current_subj, :delay 

    def initialize(prog, subj, col = 1, zeroth = [nil,nil])
      system "mkfifo /tmp/debug_machine#{uniq_id}"
      @temp_file = File.open("/tmp/debug_machine#{uniq_id}","w+")
      define_finalizer(self, lambda { system "rm /tmp/debug_machine#{uniq_id}" } )
      @delay = 0.25 
      @program = prog.to_a.dup #duplicate the subject and instruction set 
      @subj = subj.to_a.dup 
      @col = col
      first_width = @subj.map(&:to_s).map(&:length).max + 10
      inst_width = @program.map(&:to_s).map(&:length).max + 10
      @width = [[first_width, inst_width].max + 2, 30].min # a little space
      unless zeroth.compact.empty? then
        @home = zeroth
      end
      @current_inst = nil
      @current_subj = nil
      @threads = [self]
      _cache
    end

    def new_thread
      prog, subj, col, zeroth = [@program, @subj, @threads.count, @home]
      t = DebugMachine.new(prog,subj,col+1,zeroth)
      t.parent = self.parent || self
      # add to the root thread, not necessarily us
      t.parent.instance_exec(t) do |t|
        @threads << t
      end
      t
    end

    def uniq_id 
      @uniq_id ||= "#{"%x" % (Time.now.to_i + self.__id__).hash}".upcase
    end

    def _cache
      super
      @size = {:cols => `tput cols`.to_i, :rows => @program.length + 1}
      
      #commands[:line] = lambda do
      macro :line do
        smacs { "#{'q' * @size[:cols]}" }
      end

      #redraw the display area, assume we're at the beggining
      macro :clear do
        output do |str|
          (@size[:rows]).times do
            str << c.mrcup(1,0)
            str << `tput el`
          end
        end
      end
      
      macro :box do 
       output do |str|
          str << color(2) { c.line }
          str << c.clear
          str << color(2) { c.line } 
          str << "\n"
        end
      end

      macro :title do 
        output do |str|
          str << color(15) { self.to_s + "   "}
        end
      end
      true
    end    

    def draw_subject(hilight = nil)
      if @current_subj and @current_subj >= @subj.length 
        raise IndexError, "Subject index #{hilight} out of range" 
      end
      string = output do |str|
        (@size[:rows]-1).times do |idx|
          out = ""
          if idx == @current_subj
            out = color(6) { "*#{idx} : #{@subj[idx]}*" }
          else
            out = color(7) { " #{idx} : #{@subj[idx]} " } if @subj[idx]
          end
          if out.length > @width
            out.slice!(0,@width-3)
            out << "..."
          end
          str << out
          str << c.moveto(col: (@width - 2))
          str << smacs{ "x\n" }
        end
      end
    end

    def title
      output do |str|
        str << c.title
        if @message
          str << color(1) { ">  #{@message}  "} 
        end
      end
    end

    def draw_self at_col = @col
      if @current_inst and @current_inst >= @program.length
        raise IndexError, "Instruction index #{inst} out of range" 
      end
      string = output do |str|
        str << c.mrcup(1,0)
        @program.each_with_index do |inst,idx|
          str << c.moveto(col:(at_col * @width))
          out = ""
          if idx == @current_inst
            out = color(1) { " >>> #{idx}: #{inst}"}
          else
            out = color(3) { " --- " }
            out << color(7) { "#{idx}: #{inst}" }
          end
          if out.length > @width
            debugger
            out.slice!(0,@width-3)
            out << "..."
          end
          str << out
          str << c.moveto(col:((at_col + 1) * @width)-1)
          str << smacs { "x\n" }
        end
        str << c.mrcup(-(@size[:rows]),0)
      end
    end

    def puts msg
      @message = msg
      display
      str = there_and_back do |str|
        str << c.mrcup(-(@size[:rows]+1), self.to_s.length + 5)
        str << color(1) { ">  #{msg}   "}
      end
      $stdout << str
      @home
    end

    def puts_inplace msg, loc = nil
      @message = msg
      goto = loc || @home
      str = there_and_back do |str| 
        str << c.moveto(*goto)
        str << c.mrcup(-(@size[:rows]+1),0)
        str << color(2) { c.line }
        str << c.moveto(col:1)
        str << c.title
        str << color(1) { ">  #{msg}  "}
      end
      $stdout << str
      true
    end
        
    def inspect
      "#<#{self.class}:#{'0x%x' % self.__id__ << 1} @program=#{@program} @delay=#{@delay} @threads=#{(@threads.count+1 rescue "None")}>"
    end

    def to_s
      "#<#{self.class}:#{'0x%x' % self.__id__ << 1}>"
    end

    def thread t
      return self if t == nil 

      p = t.parent
      p = loop do
        op = p.parent
        break p if op == nil
      end
      p.instance_exec(t) do |th|
        @threads[@threads.index(th)]
      end
    end
    
    def display
      (parent.display and return) if parent
      @message = (@threads.count + 1) * @width
      output :to_stdout do |str|
        str << c.box if not parent #only the parent clears
        str << c.mrcup(-(@size[:rows]+1),0) #two lines
        str << c.moveto(col:1) # just for good measure
        str << title
        str << c.mrcup(1,0)
        str << draw_subject()
      end
      # save the home position returning it
      if not @threads.empty?
        collapsed = 0
        if ((@threads.count + 1) * @width) > @size[:cols]
          width = 0 
          room_for = 0
          (@threads.count + 1).times do
            if (width + @width) > @size[:cols]
              break
            else
              width += @width
              room_for += 1
            end
          end
          # draw a "collapsed thread" display
          collapsed = (@threads.count + 1) - room_for
          output :to_stdout do |str|
            str << c.mrcup(-(@size[:rows]-1),@width-2)
            (@size[:rows]-1).times do
              str << smacs { "x" * collapsed }
              str << c.mrcup(1,@width-collapsed)
            end
          end
        end
        output c.mrcup(-(@size[:rows]),0)
        @threads[collapsed..-1].each_with_index do |child,col|
          output :to_stdout do |str|
            str << child.draw_self(col+1)
          end
        end
        output c.mrcup(@size[:rows]+1,0)
      end
      @home = current_position 
    end

    def display_at row,col
      output :to_stdout do |str|
        str << c.save
        str << c.moveto(row,col)
      end
      display
      @home
    end

    def update_inplace subj = nil,inst = nil,opts = nil
      goto = opts ? (opts[:goto] || opts[:at]) : @home.dup
      goto[0] -= @size[:rows] + 1# move up the number of rows
      output :to_stdout do |str|
        str << c.save
        str << c.moveto(*goto)
      end
      update subj, inst
      output c.restore
      sleep @delay
      true
    end
        
    def update subj = nil, inst = nil
      @current_subj = subj
      @current_inst = inst
      display
      true
    end

    def close
      if @parent
        @parent.instance_exec(self) do |t|
          i = @threads.index t
          @threads[i] = nil
          @threads.compact!
        end
      end
      output :to_stdout do |str|
        str << c.save
        str << c.moveto(*@home)
        str << c.clear
        str << c.restore
      end
    end
  end
end

# enable debugging
MinimalMatch::MatchMachine.debug= true
