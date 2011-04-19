require 'tempfile'

module MinimalMatch
  class DebugMachine
    class << self
      def new_thread(p_machine)
        prog, subj, col, *zeroth = p_machine.instance_eval {
          [@program, @subj, @col, @top_line, @first_col]
        }
        r = DebugMachine.new(prog,subj,col+1,zeroth)
        r.parent = false
        r
      end

      def new_layer(p_machine,subj)
        prog, p_subj , _, tl, _= p_machine.instance_eval {
          [@program, @subj, @col, @top_line, @first_col]
        }
        tl = p_subj.length + 2 
        r = DebugMachine.new(prog,subj,1,[tl,0])
        r
      end
    end

    attr_accessor :parent
    attr_accessor :delay
    
    def color color
      str = ""
      str << `tput setaf #{color}`
      str << yield
      str << @commands[:reset] 
    end

    def there_and_back
      str = ""
      str << @commands[:save]
      str << yield
      str << @commands[:restore]
      str
    end

    def smacs
      str = ""
      str << @commands[:smacs]
      str << yield
      str << @commands[:rmacs]
      str
    end

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
      mrcup: lambda do |col,row|
        hdir = col > 0 ? :right : :left
        vdir = row > 0 ? :up : :down
        [[hdir,col],[vdir,row]].inject '' do |memo, dir|
          memo << (COMMANDS[dir[0]] * dir[1].abs)
        end
      end,
      current_position: lambda do |t|
        # holy mother of what's the fucking point of u7??
        system("stty -echo; tput u7; read -d R x; stty echo; echo ${x#??} > #{t.path}")
        temp_file.read.chomp.split(';')
      end
    }

    def initialize(prog, subj, col = 1, zeroth = [0,0])
      @temp_file = TempFile.new('debug_machine')
      @commands = COMMANDS.dup

      @delay = 0.25 
      @parent = true
      @program = prog
      @col = col
      @subj = subj
      first_width = @subj.map(&:to_s).map(&:length).max + 10
      inst_width = @program.map(&:to_s).map(&:length).max + 10
      @width = [first_width, inst_width].max

      @top_line, @first_col = @commands[:current_position]
     
      cols = `tput cols`.to_i
      rows = @program.length + 1

      @commands[:home] = lambda do
        str << `tput cup #{@top_line} #{@first_col}`
      end.call

      @commands[:info] = lambda do
        str = ""
        str << there_and_back do
          str << `tput cup #{rows + 1} 0`
        end
        str << '%s'
        str
      end.call

      @commands[:line] = lambda do
        smacs { "#{'q' * cols}" }
      end.call

      @commands[:clear] = lambda do
        str = ""
        str << @commands[:home]
        cols = `tput cols`.to_i
        str << color(2) { @commands[:line] }
        (cols * rows).times do
          str << ' ' 
        end
        str << color(2) { @commands [:line] }
        str
      end.call

      @commands[:subject] = lambda do
        str = ""
        str << @commands[:home]
        str << color(15) { self.to_s + "\n" }
        subj.each_with_index do |subj,idx|
          str << color(7) { " #{idx} : #{subj} " }
          str << `tput hpa #{@first_col + @width - 2}`
          str << smacs{ "x\n" }
        end
        str
      end.call

      @commands[:self] = lambda do
        str = ""
        @program.each_with_index do |inst,idx|
          str << `tput cup #{@top_line + idx + 1} #{(@col * @width) + @first_col}`
          str << color(3) { " --- " }
          str << color(7) { "#{idx}: #{inst}" }
          str << `tput hpa #{(@col * @width) + @first_col - 2 }`
          str << smacs { "x\n" }
        end
        str
      end.call
    end

    def draw_subject(hilight = nil)
      str = ""
      str << @commands[:subject] 
      if hilight
        str << `tput cup #{@top_line + hilight + 1} #{@first_col}`
        str << color(6) { "*#{hilight} : #{@subj[hilight]}*" }
      end
      str
    end

    def draw_self(inst = nil)
      str = ""
      str << @commands[:self] 
      if inst
        str << `tput cup #{@top_line + inst +1} #{(@col * @width) + @first_col}`
        str << color(1) { " >>>" }
      end
      str
    end

    def puts msg
      $stdout << (@commands[:info] % msg)
    end

    def display inst = nil, subj = nil
      str = ""
      str << @commands[:clear] if @parent
      str << draw_subject(subj) if subj
      str << draw_self(inst) 
      $stdout.print str
      sleep @delay 
      nil
    end

    def close
      $stdout << @commands[:end]
    end
  end
end
