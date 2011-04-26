require 'tempfile'

module MinimalMatch
  class DebugMachine
    class << self
      def new_thread(p_machine)
        prog, subj, col, *zeroth = p_machine.instance_eval {
          [@program, @subj, @col, @home]
        }
        r = DebugMachine.new(prog,subj,col+1,zeroth)
        r.parent = false
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

  class DebugMachineCache

    remove_const :COMMANDS rescue nil#TODO remove this

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
      [[hdir,col],[vdir,row]].inject '' do |memo, dir|
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

    # abstractions around common escape sequences or construction
    def output to_stdout = false
      string = ""
      yield(string) # modifiy str in place
      if to_stdout
        $stdout << string
      end
      string
    end
 
    def color color
      output do |str|
        str << c.setaf(color)
        str << yield
        str << c.reset
      end
    end

    def there_and_back
      warn "nested there_and_back" if @within
      @within = true
      string = output do |str|
        str << c.save 
        str << yield
        str << c.restore
      end
      @within = false
      string
    end

    def smacs
      output do |str|
        str << c.smacs 
        str << yield
        str << c.rmacs 
      end
    end

    
    attr_accessor :delay
    attr_reader :home
    attr_reader :parent

    def initialize(prog, subj, col = 1, zeroth = [nil,nil])
      system "mkfifo /tmp/debug_machine#{uniq_id}"
      @temp_file = File.open("/tmp/debug_machine#{uniq_id}","w+")
      @delay = 0.25 
      @parent = true
      @program = prog.dup #duplicate the subject and instruction set 
      @subj = subj.dup 
      @col = col
      first_width = @subj.map(&:to_s).map(&:length).max + 10
      inst_width = @program.map(&:to_s).map(&:length).max + 10
      @width = [first_width, inst_width].max
      
      unless zeroth.compact.empty? then
        @home = zeroth
      end
      
    _cache

    end

    def c
      @commands
    end

    def uniq_id 
      @uniq_id ||= "#{"%x" % (Time.now.to_i + self.__id__).hash}".upcase
    end

    def _cache
      @commands = DebugMachineCache.new
      @size = {:cols => `tput cols`.to_i, :rows => @program.length + 1}
      commands = {}
      commands[:size] = @size

      # this is completley fucking wrong
      commands[:info] = lambda do
        output do |str|
          str << there_and_back do
            str << c.mrcup(@size[:rows] + 1,0)
            str << c.moveto(col: 0)
          end
          str << '%s'
        end
      end.call

      commands[:line] = lambda do
        smacs { "#{'q' * @size[:cols]}" }
      end.call

      #redraw the display area, assume we're at the beggining
      commands[:clear] = lambda do
        output do |str|
          str << color(2) { commands[:line] }
          (@size[:rows]).times do
            str << c.mrcup(1,0)
            str << `tput el`
          end
          str << color(2) { commands[:line] } 
          str << "\n"
        end
      end.call

      commands[:self] = lambda do
        output do |str|
          str << c.mrcup(2,0) # avoid the top line
          @program.each_with_index do |inst,idx|
            str << c.moveto(col: (@col * @width))
            str << color(3) { " --- " }
            str << color(7) { "#{idx}: #{inst}" }
            str << c.moveto(col: ((@col + 1) * @width))
            str << smacs { "x\n" }
          end
        end
      end.call

      commands[:subject] = lambda do
        output do |str|
          str << color(15) { self.to_s + "\n" }
          str << output do |str|
            (@size[:rows] - 1).times do |idx|
              str << color(7) { " #{idx} : #{@subj[idx]} " } if @subj[idx]
              str << c.moveto(col: (@width - 2))
              str << smacs{ "x\n" }
            end
          end
        end
      end.call
      
      commands.each_pair do |meth,b|
        c = b.is_a?(Proc) ? b : lambda { b }
        @commands.define_singleton_method meth, &c
      end

      @commands
    end

    def current_position
      system("stty -echo; tput u7; read -d R x; stty echo; echo ${x#??} > #{@temp_file.path}")
      @temp_file.gets.chomp.split(';').map(&:to_i)
    end

    def draw_subject(hilight = nil)
      output do |str|
        str << c.subject 
        str << c.mrcup(-(c.subject.lines.count),0)
      end
    end

    def update_subject(hilight)
      output do |str|
        str << draw_subject
        str << output do |str|
          str << c.moveto(col: 1)
          str << c.mrcup(hilight+1,0)
          str << color(6) { "*#{hilight} : #{@subj[hilight]}*" }
          str << c.moveto(col: 1)
          str << c.mrcup(-(hilight+1),0)
        end
      end
    end

    def draw_self
      output do |str|
        str << c.self
        str << c.mrcup(-(c.self.lines.count),0)
      end
    end

    def update_self(inst)
      output do |str|
        str << draw_self
        str << output do |str|
          str << c.moveto(col: ((@col * @width)))
          str << c.mrcup(inst+1,0)
          str << c.moveto(col: ((@col * @width)))
          str << color(1) { " >>> #{inst}: #{@program[inst]}" }
          str << c.mrcup(-(inst+1),0)
        end
      end
    end
    
    def puts msg
      $stdout << (c.info % msg)
    end

    def inspect
      "#<#{self.class}:#{'0x%x' % self.__id__ << 1} @program=#{@program}> @delay=#{@delay}"
    end

    def to_s
      "#<#{self.class}:#{'0x%x' % self.__id__ << 1}>"
    end
    
    def display
      output :to_stdout do |str|
        str << c.clear if @parent
        str << c.mrcup(-(@size[:rows]+1),0) #two lines
        str << c.moveto(col:1) # just for good measure
        str << draw_subject()
        str << draw_self() 
        str << c.mrcup(@size[:rows]+3,0) #to the end!
      end
      # save the home position returning it
      @home = current_position 
    end


    def update_inplace subj,inst
      goto = opts[:goto] || opts[:at] || @home
      output :to_stdout do |str|
        str << c.moveto(goto) 
        update
      end
      sleep @delay
      true
    end
        
    def update subj, inst, opts = {}
      display
      output :to_stdout do |str|
        str << there_and_back do
          str << c.mrcup(-(@size[:rows]-1),0)
          str << c.moveto(col:1)
          str << update_subject(subj) if subj
          str << update_self(inst) if inst
        end
      end
      true
    end
  end
end
