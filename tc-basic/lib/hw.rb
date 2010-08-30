# Hardware / Step 1.
#  Input:  MHS file
#  Output: HDLs, NGC
#
#  Descr: MSS file describes componene
# Generate HDL code from MSS file.
#

require 'lib/hw/hw1platgen.rb'

class HW_c
  attr_accessor :xmp, :log_dir
  attr_reader :platgen

  def initialize (xmp_i=nil, ldir=nil)
    
    
    @log_dir = ldir unless ldir.nil?  # setup value without calling setter
    self.xmp=xmp_i unless xmp_i.nil?  # call setter function for xmp
    # execute code from callers { ... }
    yield self if block_given?  
    # after caller ended his { ... }
    create_tasks
  end
  
  def create_tasks
    if @log_dir.nil? then p "hardware.log_dir not defined"; end
    if @xmp.nil? then p "hardware.xmp not defined"; end
  
    # create logdir to store logging files
    file "#{@log_dir}" do mkdir @log_dir; end
  
    desc "1.Platgen"
    task :_hw1platgen => ["#{@log_dir}"] do  
        @platgen = Platgen_C.new { |pl|
          pl.xmp = @xmp
          pl.log_dir = @log_dir
        }

    end

    
    desc "2. Synthesis"
    task :_hw2synth => [:_hw1platgen]
    
    desc "3. Ngdbuild"
    task :_hw3ngd => [:_hw2synth]
    
    desc "4. Map"
    task :_hw4map => [:_hw3ngd]
    
    desc "5. PAR"
    task :_hw5par => [:_hw4map]
    
    desc "6. Trace"
    task :_hw6trce => [:_hw5par]

    desc "7. Bitgen"
    task :_hw7bit => [:_hw6trce]

    desc "Generate hardware"
    task :hw => [:_hw7bit]
    
    # add to each task also file task like this.
    # in such scenario we would work on file-basis
    # task :_hw2synth => [ implementation/*hdl ]
    # file "implementation/*hdl" do
    # =>  platgen ... end
    
    # file ["implementation/system.bit"]  => ["implementation/system.ncd"]do
    # end
    
  end
end
  
  


