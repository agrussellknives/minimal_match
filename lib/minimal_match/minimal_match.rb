#necessary sub files
require 'fiber'
require 'singleton'
#
%w{ minimal_match_object match_proxy match_multiplying special_literals
    array_match_data reversible_enumerator}.each { |mod| require "#{File.dirname(__FILE__)}/#{mod}"}

module MinimalMatch

  class MarkerObject < MinimalMatchObject
    # abstract position marker
    def ===
      false
    end

    def to_s
      #memoize the string value after it's calculated
      @s_val ||= lambda { self.class.to_s.gsub("Class",'') }.call
    end

    def inspect
      self.class
    end

    private :initialize
  end
  MarkerObject.__send__ :include, Singleton

  class EndClass < MarkerObject; end
  class BeginClass < MarkerObject; end

  # you can't access the array "post" from ruby code
  # so you need this to know when you're at the end of
  # the array
  class SentinelClass < MarkerObject; end
 
  Anything = MinimalMatch::AnythingClass.instance
  End = MinimalMatch::EndClass.instance
  Begin = MinimalMatch::BeginClass.instance
  Sentinel = MinimalMatch::SentinelClass.instance

  def noop; NoOp.instance(); end
    
  def compile match_array
    is = []
    match_array.each do |mi|
      i = is.length
      if mi.respond_to? :compile
        is.concat(mi.compile(i))
      else
        # so it's just a standard object
        is.concat(MatchCompile.compile(i,mi))
      end
    end
    is << [:match]
  end
  module_function :compile

  module ArrayMethods
    def match match_array
      self =~ match_array
      @last_match || false
    end

    def =~ match_array_orig
      @bind_index = 0 
      @last_match = false # starts any match operation as false

      @debug = true
      match_self = self.dup #dup self to the local so that we don't mess it up
      match_self << Sentinel
      match_array = match_array_orig.dup
    
     

      #there is no need to look past END or before BEGINh
      # ignore thie optimzation for now
      has_end, has_begin, has_epsilon = false
      match_array.find_all { |i| i.kind_of? MarkerObject }.each do |val| 
        case val
          when End
            match_array = match_array[0..match_array.index(val).prev]
            has_end = true
          when Begin
            match_array = match_array[match_array.index(val).succ..-1]
            has_begin = true
          when Repetition 
            # zero width assertions will prevent a simple length check
            # optmization. it's probably possible to figure this
            # out, but we'll skip it for now
            has_epsilon = true
        end
      end

      if not has_epsilon and match_self.length < match_array.length
         return false
      end

      
      unless has_begin
        match_array.unshift(*MatchProxy.new(Anything).non_greedy.to_a)
      end

      unless has_end
        match_array.concat(MatchProxy.new(Anything).to_a)
      end
      

      ma = MinimalMatch.compile match_array
      
      # use this function as the comparate to enable
      # recursive matching.
      cond_comp = lambda do |self_val, comp_val|
        op_sym = (self_val.is_a? Array and comp_val.is_a? Array) ? :=~ : :===
        if op_sym == :===
          r = self_val.__send__ op_sym, comp_val
        else
          r = comp_val.__send__ op_sym, self_val
        end
        r
      end
      
      p ma
      first_idx = nil
      last_idx = nil
      match_hash = {}

      pathology_count = 0
      
      #the debugger display
      ddisplay = nil

      # a simple recursive loop NFA style regex matcher
      cmp_lamb = lambda do |match_enum,self_enum, pdisplay|
        if @debug
          if ddisplay
            ddisplay = DebugMachine.new_thread(pdisplay) 
          else
            ddisplay = DebugMachine.new(match_enum.obj, self_enum.obj)
            ddisplay.display
          end
        end

        loop do
          ddisplay.puts pathology_count += 1 if @debug
          op, *args = match_enum.current
          
          ddisplay.update match_enum.index, self_enum.index if @debug


          #smells funny, but i thinkg this is actually correct
          args = (args.length == 1 ? args[0] : args) rescue false
          case op 
           when :lit # this is the only code that actually does a comparison
             break false unless cond_comp[args, self_enum.current]
             match_enum.next and self_enum.next #advance both
           when :noop
             match_enum.next #advance enumerator, but not match
             next
           when :save
             unless match_hash.has_key? *args
               match_hash[args] = { :begin => self_enum.index }
             else
               match_hash[args][:end] = self_enum.index
             end
           # not currently in use
           when :peek
             break false unless cond_comp[args, self_enum.peek]
             match_enum.next and self_enum.next #advance both
           when :match
             last_idx = self_enum.index
             throw :stop_now, true #because we don't know how deeply we are nested
           when :jump
             match_enum[args] # set the index
             next 
           when :split
             # branch1
             b1 = match_enum.dup # create a new iterator to explore the other branch
             b1.index = args.first #set the index to split location
             if cmp_lamb[b1,self_enum.dup, ddisplay]
               break true
             else
               match_enum.index = args.last
               next
             end
          end
        end
      end
      
      match_enum = ReversibleEnumerator.new ma
      self_enum = ReversibleEnumerator.new match_self

      match_enum.next and self_enum.next #start
      res = catch :stop_now do
        cmp_lamb.call match_enum, self_enum, ddisplay
      end

      ddisplay.close if ddisplay

      res and true or false
    end
  end
end
