module Errors
  class ParseError < StandardError
  end
end

class CliUtils
  include Errors
  attr_accessor :args,:command,:config

  def initialize(config_filepath=nil, commands_filepath=nil)
    init_commands(commands_filepath)
    parse_args
    init_config(filepath=nil)
  end

  def init_commands(commands_filepath)
    #TODO
    @commands = {}
  end

  def parse_args
    @args = {}
    ARGV.each_with_index {|arg, i|
      if arg[0] == '-'
        if arg[1] == '-'
          raise ParseError unless ARGV[i + 1]
          #TODO warn when the value of --foo is a command
          @args[arg[2..-1]] = processValue(ARGV[i + 1])
        else
        end
      end
    }
  end

  def init_config(config_filepath)
    #TODO
    @config = {}
  end

  def processValue(val)
    return File.open(val[1..-1],'r').read if val.start_with? '@'
    val
  end
end

puts CliUtils.new.inspect
