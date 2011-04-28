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

  def box row,col, width, height, opts = {}
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
        string = (yield).scan(/.{0,#{width}}/).join("\n")
        string.each_line do |l|
          str << c.mrcup(0,col)
          str << l
        end
      end
    end
  end

  def _cache
    @cache = CommandCache.new
  end
  private :_cache

end


module MinimalMatch
  class DebugMachine
    include TermHelper

    class << self
      def new_thread(p_machine)
        prog, subj, col, zeroth = p_machine.instance_eval {
          [@program, @subj, @threads.count, @home]
        }
        r = DebugMachine.new(prog,subj,col+1,zeroth)
        r
      end

      def new_layer(p_machine,subj)
        prog, p_subj , _, tl, _= p_machine.instance_eval {
          [@program, @subj, @col, @home]
        }
        tl = p_subj.length + 2 
        r = DebugMachine.new(prog,subj,1,[tl,0])
        r
      end
    end

    attr_reader :home
    attr_accessor:parent, :current_inst, :current_subj, :delay 

    def initialize(prog, subj, col = 1, zeroth = [nil,nil])
      system "mkfifo /tmp/debug_machine#{uniq_id}"
      @temp_file = File.open("/tmp/debug_machine#{uniq_id}","w+")
      @delay = 0.25 
      @program = prog.to_a.dup #duplicate the subject and instruction set 
      @subj = subj.to_a.dup 
      @threads = []
      @col = col
      first_width = @subj.map(&:to_s).map(&:length).max + 10
      inst_width = @program.map(&:to_s).map(&:length).max + 10
      @width = [first_width, inst_width].max + 2 # a little space
      unless zeroth.compact.empty? then
        @home = zeroth
      end
      @current_inst = nil
      @current_subj = nil
      _cache
    end

    def new_thread
      t = DebugMachine.new_thread(self)
      t.parent = self.parent || self
      t.parent.instance_exec(t) do |t|
        @threads << t
      end
      t
    end

    def c
      @cache
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
          str << color(2) { c.line }
          (@size[:rows]).times do
            str << c.mrcup(1,0)
            str << `tput el`
          end
          str << color(2) { c.line } 
          str << "\n"
        end
      end

      macro :self do 
        output do |str|
          str << c.mrcup(1,0) # avoid the top line
          @program.each_with_index do |inst,idx|
            str << c.moveto(col: (@col * @width))
            str << color(3) { " --- " }
            str << color(7) { "#{idx}: #{inst}" }
            str << c.moveto(col: (((@col + 1) * @width) - 2))
            str << smacs { "x\n" }
          end
        end
      end

      macro :title do 
        output do |str|
          str << color(15) { self.to_s + "   "}
        end
      end

      macro :subject do
        output do |str|
          str << output do |str|
            (@size[:rows]-1).times do |idx|
              str << color(7) { " #{idx} : #{@subj[idx]} " } if @subj[idx]
              str << c.moveto(col: (@width - 2))
              str << smacs{ "x\n" }
            end
          end
        end
      end
      true
    end    

    def draw_subject(hilight = nil)
      output do |str|
        str << c.subject 
        str << c.mrcup(-(@size[:rows]),0)
      end
    end

    def update_subject(hilight)
      raise IndexError, "Subject index #{hilight} out of range" if hilight >= @subj.length
      row = hilight + 1  #accounts for the box and "return" row
      @current_subj = hilight
      output do |str|
        str << draw_subject
        str << output do |str|
          str << c.moveto(col: 1)
          str << c.mrcup(row,0)
          str << color(6) { "*#{@current_subj} : #{@subj[@current_subj]}*" }
          str << c.moveto(col: 1)
          str << c.mrcup(-(row),0)
        end
      end
    end

    def draw_self
      output do |str|
        str << c.self
        str << c.mrcup(-(@size[:rows]),0)
      end
    end

    def update_self(inst)
      raise IndexError, "Instruction index #{inst} out of range" if inst >= @program.length
      @current_inst = inst
      row = inst + 1 
      output do |str|
        str << draw_self
        str << output do |str|
          str << c.moveto(col: ((@col * @width)))
          str << c.mrcup(row,0)
          str << c.moveto(col: ((@col * @width)))
          str << color(1) { " >>> #{@current_inst}: #{@program[@current_inst]}" }
          str << c.mrcup(-(row),0)
        end
      end
    end
    
    def puts msg
      display
      str = there_and_back do |str|
        str << c.mrcup(-(@size[:rows]+1), self.to_s.length + 5)
        str << color(1) { ">  #{msg}   "}
      end
      $stdout << str
      @home
    end

    def puts_inplace msg, loc = nil
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
    
    def display
      (parent.display and return) if parent
      output :to_stdout do |str|
        str << c.clear if not parent #only the parent clears
        str << c.mrcup(-(@size[:rows]+1),0) #two lines
        str << c.moveto(col:1) # just for good measure
        str << c.title
        str << c.mrcup(1,0)
        if @current_subj and @current_inst
          str << update_subject(@current_subj)
          str << update_self(@current_inst)
        else
          str << draw_subject()
          str << draw_self()
        end
        str << c.mrcup(@size[:rows]+1,0) #to the end!
      end
      # save the home position returning it
      if not @threads.empty?
        output c.mrcup(-(@size[:rows]+1),0)
        @threads.each do |child|
          output :to_stdout do |str|
            str << child.draw_self 
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
      goto = opts ? (opts[:goto] || opts[:at]) : @home
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
      display
      output :to_stdout do |str|
        str << c.mrcup(-(@size[:rows]),0)
        str << c.moveto(col:1)
        str << update_subject(subj) if subj
        str << update_self(inst) if inst
        str << c.mrcup(@size[:rows]+1,0) #to the end! leave an extra line
      end
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
    end
  end
end

#enable vm debugging
class Array
  include MinimalMatch::Debugging
  class << self
    def debug_class
      MinimalMatch::DebugMachine
    end
  end
end
