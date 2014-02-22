require 'json'

module Errors
  class ArgumentError < StandardError
  end

  class ParseError < StandardError
  end

  class MissingCommandError < StandardError
  end

  class MissingFileError < StandardError
  end
end

class CliUtils
  include Errors
  attr_accessor :commands, :command, :optional, :required, :config, :eval

  def initialize(commands_filepath=nil, config_filepath=nil, suggestions_count=nil)
    @s_count = suggestions_count || 4

    begin
      init_commands(commands_filepath)
      init_config(config_filepath)
      parse_options

      if @command
        @eval = @commands[@command]['eval']
      end

    rescue ParseError => e
      render_error e
    rescue ArgumentError => e
      render_error e
    rescue MissingFileError => e
      render_error e
    rescue MissingCommandError => e
      err = "#{e.message} is not a command. Did you mean:\n\n"
      alts = CliUtils::top_matches(e.message, @commands.keys, @s_count).map{|m| usage(m)}.uniq.join("\n")
      $stderr.puts("#{err}#{alts}")
      exit 1
    end
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
    ts = [ [''    , 'abc', 3],
           ['aaa' , 'aab', 1],
           ['aa'  , 'aab', 1],
           ['aaaa', 'aab', 2],
           ['aaa' , 'aaa', 0],
         ]

    ts.each_with_index{|arr,i|
      condition = levenshtein_distance(arr[0],arr[1]) == arr[2]
      puts "Test #{i}: #{(condition ? 'success' : 'failure')}"
    }
  end

  #TODO can return duplicates if the long and short commands are similar
  def self.top_matches(str, candidates, top=4)
    candidates.sort_by{|a| levenshtein_distance(str, a)}[0...top]
  end

  def render_error(err)
    $stderr.puts err.message
    $stderr.puts usage(@command) if @command
    exit 1
  end

  def format_json(struct)
    if (@config['defaults'] || {})['pretty_print'].to_s.downcase == 'true'
      return Json.pretty_generate(struct, {'max_nesting' => 100})
    else
      return Json.generate(struct, {'max_nesting' => 100})
    end
  end

  def init_commands(commands_filepath)
    @commands ={}
    return unless commands_filepath

    unless File.exist?(commands_filepath)
      raise MissingFileError.new("Commands File not found: #{commands_filepath}")
    end

    begin
      commands = JSON.parse(File.open(commands_filepath,'r').read)
    rescue JSON::ParserError => e
      raise ArgumentError.new("#{commands_filepath} contents is not valid JSON")
    end

    raise ArgumentError.new("#{commands_filepath} is not an array") unless commands.is_a?(Array)

    commands.each{|c|
      mb_long = c['long']
      mb_short = c['short']
      @commands[mb_long] = c if mb_long
      @commands[mb_short] = c if mb_short
    }
  end

  def parse_options
    @optional = {}
    command_index = nil
    ARGV.each_with_index {|arg, i|
      next_arg = ARGV[i + 1]

      if arg[0] == '-'
        if arg[1] == '-'
          raise ParseError.new("Missing argument to: #{arg}") unless next_arg
          @optional[arg[2..-1]] = processValue(next_arg)
        else
          @optional[tail(arg)] = true
        end
      else
        if dangling?(command_index, i, arg)
          if ARGV.find{|e| @commands.has_key?(e)}
            raise ParseError.new("Dangling command line element: #{arg}")
          else
            raise MissingCommandError.new(arg)
          end
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
          #old versions of ruby do not have a to_h array method
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

    is_value = current_index > 0 && ARGV[current_index - 1].start_with?('--')
    is_first_command = is_command?(arg) && !@command

    !(is_value || is_required || is_first_command)
  end

  def usage(command)
    c        = @commands[command]
    long     = c['long'] || ''
    short    = c['short'] ? "(#{c['short']})" : ''
    required = (c['required'] || []).map{|r| "<#{r}>"}.join(' ')

    optional = (c['optional'] || []).map{|o| "[#{o}#{o.start_with?('--') ? ' foo' : ''}]"}.join(' ')

    "#{long} #{short} #{required} #{optional}".gsub(/ +/,' ')
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
