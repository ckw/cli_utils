module Errors
  class ArgumentError < StandardError
  end

  class ParseError < StandardError
  end
end

class CliUtils
  include Errors
  attr_accessor :options,:required,:command,:config

  def initialize(config_filepath=nil, commands_filepath=nil)
    init_commands(commands_filepath)

    begin
      parse_options
    rescue ParseError => e
      render_error e
    rescue ArgumentError => e
      render_error e
    end

    init_config(filepath=nil)
  end

  def render_error(err)
    $stderr.puts err.message
    exit 1
  end

  def init_commands(commands_filepath)
    #TODO
    @commands = {'foo'=> {'required' => ['bar','baz']}}
  end

  def parse_options
    @options = {}
    command_index = nil
    ARGV.each_with_index {|arg, i|
      next_arg = ARGV[i + 1]

      if arg[0] == '-'
        base_arg = arg.gsub(/\A-+/,'')
        has_val = next_arg && !(is_command?(next_arg) || next_arg.start_with?('-'))
        @options[base_arg] = has_val ? processValue(next_arg) : true
      else
        if dangling?(command_index, i, arg)
          raise ParseError.new("Dangling command line element: #{arg}")
        end

        next if @command

        if is_command?(arg)
          @command = arg
          command_index = i
          req_keys = (@commands[@command]['required'] || [])
          req_vals = ARGV[i + 1, req_keys.length]

          err_str1 = 'Missing required arguments'
          raise ParseError.new(err_str1) unless req_keys.length == req_vals.length

          err_str2 = 'Required arguments may not begin with "-"'
          raise ParseError.new(err_str2) if req_vals.map{|v| v.chr}.include?('-')

          @required = {}
          req_keys.zip(req_vals).each{|(k,v)| @required[k] = processValue(v)}
        end
      end
    }
  end

  def dangling?(command_index, current_index, arg)
    num_req = (@commands[@command]['required'] || []).length if @command
    is_required =
      command_index &&
      (command_index + 1 + num_req) > current_index &&
      current_index > command_index

    is_value = current_index > 0 && ARGV[current_index - 1].start_with?('-')
    is_first_command = is_command?(arg) && !@command

    !(is_value || is_required || is_first_command)
  end

  def usage
    #TODO
  end

  def self.levenshtein_distance(s, t)
    return 0 if s == t
    return t.length if s.length == 0
    return s.length if t.length == 0

    a0 = (0..t.length + 1).to_a
    a1 = []

    (0..s.length - 1).each{|i|
      a1[0] = i + 1

      (0..t.length - 1).each{|j|
        cost = (s[i] == t[j]) ? 0 : 1
        a1[j + 1] = [a1[j] + 1, a0[j + 1] + 1, a0[j] + cost].min
      }
      a0 = a1.clone
    }

    return a1[t.length]
  end


  def self.test_lev
    ts = [ ['', 'abc', 3],
           ['aaa', 'aab', 1],
           ['aa', 'aab', 1],
           ['aaaa', 'aab', 2],
           ['aaa', 'aaa', 0],
         ]

    ts.each_with_index{|arr,i|
      condition = levenshtein_distance(arr[0],arr[1]) == arr[2]
      puts "Test #{i}: " << (condition ? 'success' : 'failure')
    }
  end

  def is_command?(str)
    (@commands || {}).has_key?(str)
  end

  def tail(arr)
    arr[1..-1]
  end

  def init_config(config_filepath)
    #TODO
    @config = {}
  end

  def processValue(val)
    if val.start_with? '@'
      fn = tail(val)
      raise ArgumentError.new("File not found: #{fn}") unless File.exist?(fn)
      return File.open(fn,'r').read
    end
    val
  end
end

c = CliUtils.new
puts c.inspect
