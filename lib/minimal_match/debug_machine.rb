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

    attr_accessor :parent
    attr_accessor :delay
    attr_accessor :commands #TODO rmove this
    
    def color color
      str = ""
      str << `tput setaf #{color}`
      str << yield
      str << @commands[:reset] 
    end

    def there_and_back
      warn "nested there_and_back" if @within
      @within = true
      str = ""
      str << @commands[:save]
      str << yield
      str << @commands[:restore]
      @within = false
      str
    end

    def smacs
      str = ""
      str << @commands[:smacs]
      str << yield
      str << @commands[:rmacs]
      str
    end

    remove_const :COMMANDS rescue nil#TODO remove this

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
      mrcup: lambda do |row,col|
        hdir = col > 0 ? :right : :left
        vdir = row > 0 ? :down : :up 
        [[hdir,col],[vdir,row]].inject'' do |memo, dir|
          memo << (COMMANDS[dir[0]] * dir[1].abs)
        end
      end,
      moveto: lambda do |*args|
        # pass it either a [row,col] array or a row:x, col:x opts hash.
        row, col = { :row => nil, :col => nil}.merge(args.first).values rescue args
        cmd = (col and row) ? 'cup' : (col ? 'hpa' : (row ? 'vpa' : 'home'))
        `tput #{cmd} #{col} #{row}`
      end,
    }
    def initialize(prog, subj, col = 1, zeroth = [nil,nil])
      system "mkfifo /tmp/debug_machine#{uniq_id}"
      @temp_file = File.open("/tmp/debug_machine#{uniq_id}","w+")
      @delay = 0.25 
      @parent = true
      @program = prog
      @col = col
      @subj = subj
      first_width = @subj.map(&:to_s).map(&:length).max + 10
      inst_width = @program.map(&:to_s).map(&:length).max + 10
      @width = [first_width, inst_width].max
      
      unless zeroth.compact.empty? then
        @home = zeroth
      end
      
      _elements

    end

    def uniq_id 
      @uniq_id ||= "#{"%x" % (Time.now.to_i + self.__id__).hash}".upcase
    end

    def _elements
      
      @commands = COMMANDS.dup
      @size = { :cols => `tput cols`.to_i, :rows => @program.length + 1}

      @commands[:info] = lambda do
        str = ""
        str << there_and_back do
          str << @commands[:mrcup][@size[:rows] + 1,0]
          str << @commands[:moveto][:col => 0]
        end
        str << '%s'
        str
      end.call

      # so i can get to "@socket"
      @commands[:current_position] = lambda do 
        # holy mother of what's the fucking point of u7??
        system("stty -echo; tput u7; read -d R x; stty echo; echo ${x#??} > #{@temp_file.path}")
        @temp_file.gets.chomp.split(';').map(&:to_i)
      end

      @commands[:line] = lambda do
        smacs { "#{'q' * @size[:cols]}" }
      end.call

      #redraw the display area, assume we're at the beggining
      @commands[:clear] = lambda do
        str = ""
        str << color(2) { @commands[:line] }
        (@size[:rows]).times do
          str << @commands[:mrcup][1,0]
          str << `tput el`
        end
        str << color(2) { @commands [:line] }
        str << "\n"
        str
      end.call

      @commands[:self] = lambda do
        str = ""
        str << @commands[:mrcup][2,0] # avoid the top line
        @program.each_with_index do |inst,idx|
          str << @commands[:moveto][:col => (@col * @width)]
          str << color(3) { " --- " }
          str << color(7) { "#{idx}: #{inst}" }
          str << @commands[:moveto][:col => ((@col + 1) * @width)]
          str << smacs { "x\n" }
        end
        str
      end.call

      @commands[:subject] = lambda do
        str = "" 
        str << color(15) { self.to_s + "\n" }
        (@size[:rows] - 1).times do |idx|
          str << color(7) { " #{idx} : #{@subj[idx]} " } if @subj[idx]
          str << @commands[:moveto][:col => (@width - 2)]
          str << smacs{ "x\n" }
        end
        str
      end.call
      true
    end

    def draw_subject(hilight = nil)
      str = ""
      if not hilight
        str << @commands[:subject]
        # end at the top
        str << @commands[:mrcup][-(@commands[:subject].lines.count),0]
      else
        str << @commands[:moveto][:col => 1]
        str << @commands[:mrcup][hilight+1,0]
        str << color(6) { "*#{hilight} : #{@subj[hilight]}*" }
        str << @commands[:moveto][:col => 1]
      end
      #end at the top
      str
    end

    def draw_self(inst = nil)
      str = ""
      if not inst
        str << @commands[:self]
        #end at the top
        str << @commands[:mrcup][-(@commands[:self].lines.count),0]
      else
        str << @commands[:moveto][:col => @first_col]
        str << @commands[:mrcup][inst+1,0]
        str << @commands[:moveto][:col => ((@col * @width))]
        str << color(1) { " >>>" }
      end
      str
    end

    def puts msg
      $stdout << (@commands[:info] % msg)
    end

    def run command, *args
      x = @commands[command]
      str = ""
      if x.respond_to? :call
        str << @commands[command][*args]
      else
        str << @commands[command]
      end
      str
    end
    
    def display
      str = ""
      if @home
        @commands[:moveto][*@home]
      end
      str << @commands[:clear] if @parent
      str << @commands[:mrcup][-(@size[:rows]+1),0] #two lines
      str << @commands[:moveto][col:1] # just for good measure
      str << draw_subject()
      str << draw_self() 
      str << @commands[:mrcup][@size[:rows]+3,0] #to the end!
      sleep 0.1
      $stdout.print str
      @home = @commands[:current_position][]
      @home
    end

    def update subj,inst opts = {}
      in_place = opts[:in_place] || opts[:inplace]
      goto = opts[:goto] || opts[:at]
      # incase you're running this in irb or something, you can do offby: 2
      # and it will move up an extra two lines
      str = ""
      display unless goto or in_place
      str = there_and_back do
        str << @commands[:moveto][*goto] if goto
        str << @commands[:mrcup][*@home] if in_place
        str << @commands[:mrcup][-(@size[:rows]+1),0] #top!
        str << @commands[:moveto][col:1]
        str << draw_subject(subj) if subj
        str << draw_self(inst) if inst
      end
      $stdout.print str
      true
    end

    def close
      $stdout << @commands[:end]
    end
  end
end
