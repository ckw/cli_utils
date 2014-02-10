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
    ARGV.each_with_index {|arg, i|
      next_arg = ARGV[i + 1]

      if arg[0] == '-'
        if next_arg && !(is_command?(next_arg) || next_arg.start_with?('-'))
          @options[arg.gsub(/\A-+/,'')] = processValue(next_arg)
        else
          @options[arg.gsub(/\A-+/,'')] = true
        end
      else
        next if @command

        if is_command?(arg)
          @command = arg
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
