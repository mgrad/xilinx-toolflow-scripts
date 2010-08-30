# Wrapper around 'platgen' command

require 'lib/open3.rb'

class Platgen_C
  class << self
  attr_accessor :xmp, :log_dir
  attr_accessor :program, :args, :log_file
  attr_reader :log
end
  def initialize(xmp=nil, log_dir=nil, log_file=nil)
    # init(xmp, log_dir)
    @log_file = log_file
    yield self if block_given?  # execute code from callers { ... }
    p @log_file
    # after callers { ... } execution
    # run
  end
  
  def init(xmp, log_dir)
    @xmp = xmp
    @program = "platgen"
    @log_dir = log_dir 
    @log_file = log_file || @program << ".log"

  end
  
  def args
    args = Array.new
    args.push("-p " << @xmp.Device << @xmp.Package << @xmp.SpeedGrade)
    args.push("-lang " << @xmp.HdlLang.downcase)
    args.push("-log " << @log_dir << @log_file)
    args.push(xmp.MHSFile)

  end
  
  def log
  end

  def run
      cmd = %Q[#{@program} #{args.join(' ')}]
      Open3.popen3(@cmd) { |stdin, stdout, stderr|
        while line = stdout.gets
          print ":", line
        end
      }
  end
end

if __FILE__ == $0
  require 'lib/xmp.rb'
  @xmp = XMP_c.new('udi/system.xmp')
  Platgen_C.new(@xmp)
end