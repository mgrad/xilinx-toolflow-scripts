#!/usr/bin/env ruby

if __FILE__ == $0
   require "#{File.dirname(__FILE__)}/lib_misc.rb"
   require "#{File.dirname(__FILE__)}/lib_xmp.rb"
end


# -------------------------------------- #
# Automatically pickup confguration
# -------------------------------------- #
ORIG_DIR = ENV['PWD']                            # dir from where you issue rake command
XILMAKE_DIR = File.expand_path(File.dirname(__FILE__))             # dir where are rakefiles
XMP_FILE = find_xmpfile_location
DESIGN_DIR = File.dirname(XMP_FILE)
#DESIGN_DIR = "."

# -------------------------------------- #
# change this if needed
# -------------------------------------- #
DEBUG = 1
EXCLUDE_HDL = "busmacro|system_stub.vhd"           # don't synthesis these files from hdl/* dir
TMPDIR      = "#{DESIGN_DIR}/_xilmake"


# -------------------------------------- #
# Parse XMP file & setup some constants
# -------------------------------------- #
@xmp = XMP_c.new(XMP_FILE)
PARTNAME       = "#{@xmp.Device}#{@xmp.Package}#{@xmp.SpeedGrade}"
UCFFILE        = @xmp.UcfFile
ELF_RESULTFILE = @xmp.Executable
CPU            = @xmp.Processor
TOPLEVEL_INSTANCE    = @xmp.TopInst
TOPLEVEL = TOPLEVEL_INSTANCE.gsub(/_i$/,'')

# -------------------------------------- #
# not neccessary change this
# -------------------------------------- #
INCLUDE_DIR    = "#{DESIGN_DIR}/x_include"             # keep here any project specific files
#BMM_RESULTSDIR = "#{DESIGN_DIR}/implementation/bmm"    # builded with 2.ngd
BMM_RESULTSDIR = "implementation/bmm"    # builded with 2.ngd
NGC_RESULTSDIR = "#{DESIGN_DIR}/implementation/1.ngc"
NGD_RESULTSDIR = "#{DESIGN_DIR}/implementation/2.ngd"
NCD_RESULTSDIR = "#{DESIGN_DIR}/implementation/3.ncd"
PAR_RESULTSDIR = "#{DESIGN_DIR}/implementation/4.par"
TRC_RESULTSDIR = "#{DESIGN_DIR}/implementation/5.trc"
BIT_RESULTSDIR = "#{DESIGN_DIR}/implementation/6.bit"
ELF_RESULTSDIR = "#{DESIGN_DIR}/implementation/7.sw"
PRJ_RESULTSDIR = "#{DESIGN_DIR}/implementation/8.prj"


# -------------------------------------- #
# dont change that
# results file for each stage
# -------------------------------------- #
BMM_RESULTFILE = "#{BMM_RESULTSDIR}/#{TOPLEVEL}.bmm"        # builded with 2.ngd
BD_RESULTFILE  = "#{BIT_RESULTSDIR}/#{TOPLEVEL}_bd.bmm"     # builded with 6.bit
NGC_RESULTFILE = "#{NGC_RESULTSDIR}/#{TOPLEVEL}.ngc"
NGD_RESULTFILE = "#{NGD_RESULTSDIR}/#{TOPLEVEL}.ngd"
NCD_RESULTFILE = "#{NCD_RESULTSDIR}/#{TOPLEVEL}.ncd"
PCF_RESULTFILE = "#{NCD_RESULTSDIR}/#{TOPLEVEL}.pcf"
PAR_RESULTFILE = "#{PAR_RESULTSDIR}/#{TOPLEVEL}.ncd"
TRC_RESULTFILE = "#{TRC_RESULTSDIR}/#{TOPLEVEL}.twx"
BIT_RESULTFILE = "#{BIT_RESULTSDIR}/#{TOPLEVEL}.bit"
PRJ_RESULTFILE = "#{PRJ_RESULTSDIR}/#{TOPLEVEL}.bit"

# -------------------------------------- #
# temporary files, logfiles and others will 
# be kept here (seperated from resultfiles)
# you can change that if needed
# -------------------------------------- #
MAK_SCRATCHDIR = "#{TMPDIR}/scratch-makefile"
GEN_SCRATCHDIR = "#{TMPDIR}/scratch-generator"
DOW_SCRATCHDIR = "#{TMPDIR}/scratch-dow"
NGC_SCRATCHDIR = "#{NGC_RESULTSDIR}/scratch"
NGD_SCRATCHDIR = "#{NGD_RESULTSDIR}/scratch"
NCD_SCRATCHDIR = "#{NCD_RESULTSDIR}/scratch"
PAR_SCRATCHDIR = "#{PAR_RESULTSDIR}/scratch"
TRC_SCRATCHDIR = "#{TRC_RESULTSDIR}/scratch"
BIT_SCRATCHDIR = "#{BIT_RESULTSDIR}/scratch"
PRJ_SCRATCHDIR = "#{PRJ_RESULTSDIR}/scratch"
ELF_SCRATCHDIR = "#{ELF_RESULTSDIR}/scratch"

# -------------------------------------- #
# guards, they will be created after 
# running: makefile, generator tasks
# -------------------------------------- #
MAKEFILE_GUARD = "#{TMPDIR}/_touch_makefile"
GEN_GUARD = "#{TMPDIR}/_touch-generator"

if __FILE__ == $0
   comment = 0;
   fn = File.open(__FILE__)
   fn.each do |line|
      if line =~ /^\s?#/ 
         puts "\n" if comment == 0
         puts line
         comment = 1
      elsif line =~ /^(\S+)\s+=/
         comment = 0;
         var = $1
         if var.upcase == var
            printf("\t%-20s = %s\n",var, eval(var));
            # puts "#{var} = #{eval(var)}"
         end
      else
         comment = 0;
      end
   end

   # self.type.constants.sort.each { |c|
   #   if c.upcase == c
   #      puts "#{c} = #{eval(c)}"
   #   end
   #}
end

