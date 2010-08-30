#!/usr/bin/env ruby

# Define a packgate task library to generate Xilinx EDK project
#
# <b>Main entries are</b>
#
# [<b>:all</b>] 
#   Create a bitstream which consits of hardware and software together
#
# [<b>:run</b>] 
#   Reprogramm FPGA with bitstream
#
# [<b>:gen_hw</b>] 
#   Generate bitfile with hardware
#
# [<b>:gen_sw</b>] 
#   Generate executable from software
#
# <b>Generating HW in details.</b>
#
#  1. <b>:_read_xmp</b> Read XMP file
#   Input file: *.xmp 
#
#  2. <b>:_gen_hdl</b>  Use 'platgen' to generate hdl file
#   Input  file: *.mhs (*.mpd, *.pao)
#   Output file: *.hdl
#
#    Platform Generator (Platgen) compiles the high-level description of your embedded
#    processor system into an HDL netlist that can be implemented in a target FPGA device.
#    - generates top level vhdl file, and connects signals from mhs component busses in that file
#    - invokes xst (to produce ngc for each component but NOT for WHOLE system)
#    - generates BBM (bram memory map) (file with addresses of BRAM memory)
#
#
#  3. [<b>:_gen_xst</b>]  Use 'xst' to synthesize hdl files 
#   Input  file: *.hdl
#   Output file: *.ngc
#
#  4. [<b>:_gen_ngd</b>] Use 'ngdbuild' to
#   - apply constrain file *.ucf 
#   - merge together *.ngc files
#   Input  file: *.ngc, *.ucf
#   Output file: *.ngd
#
#    The NGD file contains a logical description of the design that includes both the hierarchical
#    components used to develop the design and the lower level Xilinx primitives.
#    The NGD file also contains any number of NMC (macro library) files, each of which contains the definition of a physical macro. 
#
#  5. [<b>:_gen_map</b>] Use 'map' to map logic design to Xilinx fpga resources.
#   Input  file: *.ngd
#   Output file: *.ncd
#
#
#  6. [<b>:_gen_par</b>] Use 'par' to place (placer) components and route (router) wires
#   Input  file: *.ncd *.pcf
#   Output file: *.par
#
#   During placement, PAR places components into sites based on factors such as constraints 
#   specified in the PCF file, the length of connections, and the available routing resources. 
#
#   After placing the design, PAR executes multiple phases of the router. The router performs 
#   a converging procedure for a solution that routes the design to completion and meets 
#   timing constraints. Once the design is fully routed, PAR writes an NCD file, which can be 
#   analyzed against timing. 
#
#
#  7. [<b>:_gen_trc</b>] Use 'trace' to analyze and check timings (statistics)
#   Input  file: *.par
#   Output file: *.trc
#   
#  8. [<b>:_gen_bit</b> Use 'bitgen' to generate final bitstream
#   Input  file: *
#   Output file: *.bit

require 'rake'
require 'rake/tasklib'

require "./lib/xmp.rb" # read xmp file
require "./lib/hw.rb"  # generate hardware

module Rake     # extending module Rake

class XilMake < TaskLib 
  # Access to xmp configuration
  attr_reader :xmp


  # Constructor
  def initialize(xmp_file_i = nil)
    self.xmp_file = xmp_file_i   # call setter function xmp_file=
    yield self if block_given?   # execute code from callers { ... }
  end


  # Setter for xmp_file
  def xmp_file=(xmp_file_i)
    @xmp_file = xmp_file_i    # save
    create_tasks unless xmp_file_i.nil?
  end
  
  
  # Create xilinx tasks
  def create_tasks
    # parse xmp configuration
    @xmp = XMP_c.new(@xmp_file)
    # p "XilMake: #{@xmp.Device}"
    # @xmp.Device= "abcd"
    # p "XilMake: #{@xmp.Device}"
    
    Dir.chdir(File.dirname(@xmp_file))
    
    # create hardware tasks
    # @hw = HW_c.new { |h|
    #   h.xmp = @xmp
    #   h.log_dir = "./_logs_hw/"
    # }
    
  end
end
end

if __FILE__ == $0
  Rake::XilMake.new do |xil|  
      xil.xmp_file= 'udi/system.xmp'
  end
end

