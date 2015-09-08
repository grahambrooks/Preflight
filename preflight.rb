class String
  def black;
    "\e[30m#{self}\e[0m"
  end

  def red;
    "\e[31m#{self}\e[0m"
  end

  def green;
    "\e[32m#{self}\e[0m"
  end

  def brown;
    "\e[33m#{self}\e[0m"
  end

  def blue;
    "\e[34m#{self}\e[0m"
  end

  def magenta;
    "\e[35m#{self}\e[0m"
  end

  def cyan;
    "\e[36m#{self}\e[0m"
  end

  def gray;
    "\e[37m#{self}\e[0m"
  end

  def bg_black;
    "\e[40m#{self}\e[0m"
  end

  def bg_red;
    "\e[41m#{self}\e[0m"
  end

  def bg_green;
    "\e[42m#{self}\e[0m"
  end

  def bg_brown;
    "\e[43m#{self}\e[0m"
  end

  def bg_blue;
    "\e[44m#{self}\e[0m"
  end

  def bg_magenta;
    "\e[45m#{self}\e[0m"
  end

  def bg_cyan;
    "\e[46m#{self}\e[0m"
  end

  def bg_gray;
    "\e[47m#{self}\e[0m"
  end

  def bold;
    "\e[1m#{self}\e[21m"
  end

  def italic;
    "\e[3m#{self}\e[23m"
  end

  def underline;
    "\e[4m#{self}\e[24m"
  end

  def blink;
    "\e[5m#{self}\e[25m"
  end

  def reverse_color;
    "\e[7m#{self}\e[27m"
  end
end

class FileChange
  attr_accessor :type, :filepath

  def initialize(type, filepath)
    @type = type
    @filepath = filepath
  end
end

class ChangesCommand
  attr_accessor :cmd

  def initialize(&block)
    instance_eval &block if block_given?
  end

  def command(cmd)
    self.cmd = cmd
  end

  def changes
    result = []
    raw = `#{cmd}`

    raw.each_line do |line|
      case line[0]
        when 'M'
          result << FileChange.new(:MODIFIED, line.sub(/^M\s+/, '').strip)
        when 'A'
          result << FileChange.new(:ADDED, line.sub(/^A\s+/, '').strip)
        when 'D'
          result << FileChange.new(:DELETED, line.sub(/^D\s+/, '').strip)
      end
    end
    result
  end
end


class PreFlightRule
  attr_accessor :regex, :change_types, :severity, :warning_message

  def initialize(regex, &block)
    self.regex = regex

    instance_eval &block if block_given?
  end

  def on(change_types)
    self.change_types = change_types
  end

  def level(severity)
    self.severity =severity
  end

  def message(warning_message)
    self.warning_message = warning_message
  end

  def match(change, levels, comments)
    if change.type == change_types
      if change.filepath =~ regex
        comments << levels[severity].format(warning_message)
      end
    end
  end
end

class Colorize
  attr_accessor :fg_color, :bg_color

  def initialize(fg_color, bg_color = nil)
    self.bg_color = bg_color
    self.fg_color = fg_color
  end

  def format(message)
    if !bg_color.nil?
      "\e[#{fg_color}m\e[#{bg_color}m#{message}\e[0m"
    else
      "\e[#{fg_color}m#{message}\e[0m"
    end
  end
end

class PreFlight
  attr_accessor :rules, :levels, :command
  attr_accessor :rules, :levels, :command


  def initialize(filename)
    self.rules = []
    self.levels = {RED: Colorize.new(31)}
    self.command = ChangesCommand.new do
      command 'git diff --name-status'
    end

    contents = File.read(filename)
    instance_eval(contents, filename, 0)
  end

  def changeset(&block)
    self.command = ChangesCommand.new(&block)
  end

  def rule(regex, &block)
    self.rules << PreFlightRule.new(regex, &block)
  end

  def assessment(name, fg_color, bg_color)
    self.levels[name] = Colorize.new(fg_color, bg_color)
  end

  def check
    changes = command.changes

    report_check changes
  end

  def report_check(changes)
    column_width = 0
    changes.each do |c|
      column_width = [column_width, c.filepath.length].max
    end

    column_width += 2

    changes.each do |change|
      comments = []
      self.rules.each do |rule|
        rule.match(change, self.levels, comments)
      end

      if comments.length > 0
        print change.filepath.ljust(column_width).blue
        puts comments[0]

        comments.pop(comments.length-1).each do |comment|
          print ''.ljust(column_width)
          puts comment
        end
      else
        print change.filepath.ljust(column_width).blue
        puts 'Nothing to note'.green
      end

    end
  end


  class << self

    def run
      puts 'Preflight checks'.bold
      puts

      if File.exist? '.preflight'
        preflight = PreFlight.new('.preflight')

        preflight.check
      else

        puts instructions.blue
      end
    end

    def instructions;
      <<EOS

Preflight uses a local '.preflight' file to define its behaviour using a ruby DSL

To define a changeset command for Git use the changeset command like this:

changset do
  command 'git diff --name-status'
end

You can define or redefine fixed assessment values to use in your rules. The numbers refer to ANSI
escape code (white text on red background):

assessment :RED, 37, 41

See https://en.wikipedia.org/wiki/ANSI_escape_code for details

Rules define a regular expression to match change files. Use :ADDED for new filles :MODIFIED for files that
have changed and :DELETED for ... yep deleted files.

rule /pom.xml/ do |p|
  on :ADDED
  level :RED
  message "Your custom message here"
end

EOS
    end
  end
end

PreFlight.run
