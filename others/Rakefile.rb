#!/usr/bin/env ruby

# category of tasks
CAT_GEN  = 0
CAT_HW   = 1
CAT_SW   = 2
CAT_PRJ  = 3

require 'find'
require 'fileutils'
require 'lib_misc'
require 'lib_xmp'
require 'xilmake.conf'

require 'lib_synthesis'
require 'lib_generator'

# extend tasks with category
class Rake::Task
   attr_accessor :category
end

task :default do
   #   Rake::Task.tasks.each { |t| p t.category }
   #   display_tasks.each { |t|
   #     printf "%s | %s \n", t.name,  t.comment
   #     printf "%s | %s \n", t.name,  t.comment
   #   }
   #   exit
   Rake.application.options.show_task_pattern = //
   Rake.application.display_tasks_and_comments
   #   puts %x[rake -T]
end

# ----------------------- prolog tasks ----------------------- #

# it will be always executed when runned (because of dependencies)
task :makefile! do makefile_generator end
desc "a.Create new Makefiles"
task :makefile do |t|
   t.category = CAT_GEN
   unless checker_and([
      %q{File.file? MAKEFILE_GUARD},
      %q{File.file? "system.make"},
      %q{File.file? "system_incl.make"},
      %q{File.mtime("system.mhs") < File.mtime(MAKEFILE_GUARD)},
      %q{File.mtime("system.mss") < File.mtime(MAKEFILE_GUARD)},
      %q{File.mtime("system.xmp") < File.mtime(MAKEFILE_GUARD)}
   ])
   Rake::Task[:makefile!].execute(nil)
   FileUtils.touch(MAKEFILE_GUARD)
else
   #      printf("%-10s %s\n","#{t.name}:", "No modification needed.")
end

FileUtils.mkdir_p(MAK_SCRATCHDIR) unless File.directory? MAK_SCRATCHDIR
FileUtils.mv("system.log", "#{MAK_SCRATCHDIR}/") if File.file? "system.log"
end


# it will be always executed when runned (because of dependencies)
task :generator! do generator end
desc "b.Create HDL files, BMM files (& projects for synthesising hdls)"
task :generator do |t|
#   t.category = CAT_GEN
unless checker_and([
   %q{File.file? GEN_GUARD},
   %q{File.file? BMM_RESULTFILE},
   %q{Dir["hdl/*vhd"].size  >=  Dir["#{TMPDIR}/hdl/*vhd"].size},
   %q{Dir["synthesis/*scr"].size >= Dir["#{TMPDIR}/synthesis/*scr"].size},
   %q{Dir["synthesis/*prj"].size >= Dir["#{TMPDIR}/synthesis/*prj"].size},
   #      %q{Dir["synthesis/*lso"].size == Dir["#{TMPDIR}/synthesis/*lso"].size},
   %q{File.mtime("system.mhs") < File.mtime(GEN_GUARD)},
   %q{File.mtime("system.mss") < File.mtime(GEN_GUARD)},
   %q{File.mtime("system.xmp") < File.mtime(GEN_GUARD)}
])
Rake::Task[:generator!].invoke(nil)
FileUtils.touch(GEN_GUARD)    # changes mtime
else
# printf("%-10s %s\n","#{t.name}:", "No modification needed.")
end
end


# ----------------- startup - always run-------------- #
# This will be always executed during each script execution.
# Even if we dont specify makefile task.
# We generate here tasks automatically from project design sources.
Dir.chdir(DESIGN_DIR)
unless (File.file? XMP_FILE)
$stderr.puts "change directory to main"
exit
end

FileUtils.mkdir_p(TMPDIR) unless File.directory? TMPDIR
FileUtils.mkdir_p(INCLUDE_DIR) unless File.directory? INCLUDE_DIR

# ----------------- #
# automatically dynamicly build synthesis tasks
task :startup => [:generator] do |t|
puts t.investigation() if DEBUG
create_synthesis_tasks      # upon generated files build ngc tasks
end
Rake::Task[:startup].invoke(nil)



# ----------------------- hardware tasks ----------------------- #
# synthesis stub main task
desc "1.Synthesis all"
task :ngc => NGC_RESULTFILE do
|t| t.category = CAT_HW
# cmd = %Q[find "#{TMPDIR}/implementation" -type f | xargs -I'{}' ln -sf {} "#{INCLUDE_DIR}/" ] # no timestams with syml
cmd = %Q[find "#{TMPDIR}/implementation" -type f | xargs -I'{}' cp -pf {} "#{INCLUDE_DIR}/"]
%x[#{cmd}]
end

# ----------------- #
# ngdbuild
# input: *ucf, *ngc's
# output: *ngd

task :empty do

end

desc "2.Merge together components into system & apply UCF & translage ngc -> ngd"
task :ngd => NGD_RESULTFILE do |t| t.category = CAT_HW end

# it does not depend on :ngc but on NGC_RESULTFILE. :ngc will always trigger task.
file NGD_RESULTFILE => [:ngc, BMM_RESULTFILE, UCFFILE] do |t|
logfile =  "#{NGD_RESULTSDIR}/#{TOPLEVEL}.bld"

printf("%-10s %s\n","ngd:", "generating..")
FileUtils.mkdir_p(NGD_RESULTSDIR) unless File.directory? NGD_RESULTSDIR
cmd = %Q[ngdbuild -sd #{INCLUDE_DIR} -p #{PARTNAME} -bm #{BMM_RESULTFILE} -uc #{UCFFILE} #{NGC_RESULTFILE} #{t.name} ]
p cmd
%x[#{cmd}]
if $?.exitstatus != 0
msg = "#-- \t Error: check '#{logfile}' for details.\n"
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
$stderr.print(msg)
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
puts %x[tail #{logfile}]
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
exit
end

# move netlist
FileUtils.mv("netlist.lst", "#{NGD_RESULTSDIR}/") if File.file? "netlist.lst"

# move logfiles & others to scratch (clean)
FileUtils.mkdir_p(NGD_SCRATCHDIR) unless File.directory? NGD_SCRATCHDIR
FileUtils.mv(logfile, "#{NGD_SCRATCHDIR}/") if File.file? logfile
end

# ----------------- #
# mapper
# input: *ngd, *nmc
# output: *pcf, *ncd, *mrp, *ngm
desc "3.Convert logic design to FPGA cells (LUTs, I/O, etc)"
task :ncd => NCD_RESULTFILE

file NCD_RESULTFILE => :ngd do |t|
printf("%-10s %s\n","map:", "generating .. (it will take long time!)")
# printf("%-10s %s\n","map:", "generating .. (it will take long time - for all routes!)")
FileUtils.mkdir_p(NCD_RESULTSDIR) unless File.directory? NCD_RESULTSDIR

# if there is already design use it as guide mapping (template)
if File.exists? NCD_RESULTFILE
fname = File.basename(NCD_RESULTFILE)
# prev_fname ="#{NCD_RESULTSDIR}/prev_#{fname}"
prev_fname ="#{NCD_RESULTSDIR}/prev_run.ncd"
FileUtils.mv(NCD_RESULTFILE, prev_fname)
#      cmd = %Q[map -gf #{prev_fname} -gm incremental ]
end if
cmd = %Q[map -detail -o #{t.name} -uc #{UCFFILE} -pr b  #{NGD_RESULTFILE} #{PCF_RESULTFILE}]
# cmd = %Q[map -u -detail -o #{t.name} -uc #{UCFFILE} -pr b -ol high -timing #{NGD_RESULTFILE} #{PCF_RESULTFILE}]
# p cmd
%x[#{cmd}]
if $?.exitstatus != 0
logfile = "#{NCD_RESULTSDIR}/#{TOPLEVEL}.{mrp,map}"
msg = "#-- \t Error: check '#{logfile}' for details.\n"
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
$stderr.print(msg)
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
puts %x[tail #{logfile}]
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
exit
end

# move logfiles & others to scratch (clean)
FileUtils.mkdir_p(NCD_SCRATCHDIR) unless File.directory? NCD_SCRATCHDIR
[ ".mrp", ".map"].each { |ext|
f = "#{NCD_RESULTSDIR}/#{TOPLEVEL}#{ext}"
FileUtils.mv(f, "#{NCD_SCRATCHDIR}/") if File.file? f
}
FileUtils.mv("xilinx_device_details.xml", "#{NCD_SCRATCHDIR}/") if File.file? "xilinx_device_details.xml"
end



# ----------------- #
# place and route (par)
# input: *pcf, *ncd
# o:0
# output: *ncd, *par, *pad, *unroutes, *xpi
desc "4.Place design and route it in FPGA"
task :par => PAR_RESULTFILE

file PAR_RESULTFILE => :ncd do |t|
printf("%-10s %s\n","par:", "generating.. (it will take long time)")
FileUtils.mkdir_p(PAR_RESULTSDIR) unless File.directory? PAR_RESULTSDIR
prev_fname ="#{NCD_RESULTSDIR}/prev_run.ncd"
# cmd = %Q[par -w -ol high -uc #{UCFFILE} #{NCD_RESULTFILE} #{t.name} #{PCF_RESULTFILE}]
cmd = %Q[par -w -ol std -uc #{UCFFILE} #{NCD_RESULTFILE} #{t.name} #{PCF_RESULTFILE}]
# p cmd
%x[#{cmd}]
if $?.exitstatus != 0
logfile = "#{PAR_RESULTSDIR}/#{TOPLEVEL}.par"
msg = "#-- \t Error: check '#{logfile}' for details.\n"
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
$stderr.print(msg)
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
puts %x[tail #{logfile}]
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
exit
end

# move logfiles & others to scratch (clean)
FileUtils.mkdir_p(PAR_SCRATCHDIR) unless File.directory? PAR_SCRATCHDIR
[ ".pad", ".par", ".xpi", "_pad.csv", "_pad.txt" ].each { |ext|
file = "#{PAR_RESULTSDIR}/#{TOPLEVEL}#{ext}"
FileUtils.mv(file, "#{PAR_SCRATCHDIR}/") if File.file? file
}
FileUtils.mv("timing.twr", "#{PAR_SCRATCHDIR}/") if File.file? "timing.twr"
end

# ----------------- #
# trace (Verifies that the design meets timing constraints)
# input: *pcf, *ncd
# output: *twr, *twx
desc "5.Verify that the design meets timing constraints"
task :trc => TRC_RESULTFILE

file TRC_RESULTFILE => :par do |t|
printf("%-10s %s\n","trc:", "veryfing timings constraints")
FileUtils.mkdir_p(TRC_RESULTSDIR) unless File.directory? TRC_RESULTSDIR
FileUtils.mkdir_p(TRC_SCRATCHDIR) unless File.directory? TRC_SCRATCHDIR
logfile = "#{TRC_SCRATCHDIR}/#{TOPLEVEL}.twr"
%x[trce -e 3 -o #{logfile} -xml #{t.name} #{PAR_RESULTFILE} #{PCF_RESULTFILE}]
if $?.exitstatus != 0
msg = "#-- \t Error: check '#{logfile}' for details.\n"
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
$stderr.print(msg)
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
puts %x[tail #{logfile}]
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
exit
end
end

# ----------------- #
# bitgen
# input: *ut, *ncd, *pcf
# output: *bgn, *drc, *bit

desc "6.Generate hardware bitfile"
task :bit => BIT_RESULTFILE

file BIT_RESULTFILE  => :trc do |t|
printf("%-10s %s\n","bit:", "generating..")
bdfile = File.basename(BD_RESULTFILE)
bd_src_file = "#{BMM_RESULTSDIR}/#{bdfile}"
bd_dst_file = BD_RESULTFILE

p bd_src_file
p bd_dst_file

File.delete(bd_src_file) if File.symlink? bd_src_file
FileUtils.mkdir_p(BIT_RESULTSDIR) unless File.directory? BIT_RESULTSDIR

cmd = %Q[ bitgen -w -f etc/bitgen.ut #{PAR_RESULTFILE} #{t.name} #{PCF_RESULTFILE} ]
p cmd
%x[ #{cmd}]

if $?.exitstatus != 0
logfile = "#{BIT_RESULTSDIR}/#{TOPLEVEL}.bgn"
msg = "#-- \t Error: check '#{logfile}' for details.\n"
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
$stderr.print(msg)
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
puts %x[tail #{logfile}]
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
exit
end

FileUtils.mv(bd_src_file, bd_dst_file) if File.file? bd_src_file
File.symlink(bd_dst_file, bd_src_file) unless File.symlink? bd_src_file

# move logfiles & others to scratch (clean)
FileUtils.mkdir_p(BIT_SCRATCHDIR) unless File.directory? BIT_SCRATCHDIR
[ ".drc", ".bgn" ].each { |ext|
file = "#{BIT_RESULTSDIR}/#{TOPLEVEL}#{ext}"
FileUtils.mv(file, "#{BIT_SCRATCHDIR}/") if File.file? file
}
FileUtils.mv("xilinx_device_details.xml", "#{BIT_SCRATCHDIR}/") if File.file? "xilinx_device_details.xml"
end

# ----------------------- software tasks ----------------------- #
desc "7.Generate application"
task :sw => ELF_RESULTFILE

file ELF_RESULTFILE => :makefile  do |t|
FileUtils.mkdir_p(ELF_SCRATCHDIR) unless File.directory? ELF_SCRATCHDIR
logfile = "#{ELF_SCRATCHDIR}/build-sw.log"
FileUtils.rm(logfile) if File.exists? logfile
%x[(make -f system.make program 2>&1) > #{logfile}]
if $?.exitstatus != 0
msg = "#-- \t Error: check '#{logfile}' for details.\n"
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
$stderr.print(msg)
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
puts %x[tail #{logfile}]
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
exit
end
printf("%-10s %s\n","sw:", "creating.. #{ELF_RESULTFILE}") if IO.readlines(logfile).size != 1

# link results
FileUtils.mkdir_p(ELF_RESULTSDIR) unless File.directory? ELF_RESULTSDIR
dst_file = "#{ELF_RESULTSDIR}/#{File.basename(ELF_RESULTFILE)}"
File.symlink(ELF_RESULTFILE, dst_file) unless File.symlink? dst_file

# move logfiles & others to scratch (clean)
FileUtils.mv("libgen.log", "#{ELF_SCRATCHDIR}/") if File.file? "libgen.log"
end


# ----------------------- merge sw + hw ----------------------- #
desc "8.Merge hw & sw"
task :prj => PRJ_RESULTFILE

file PRJ_RESULTFILE => [:sw, :bit] do |t|
printf("%-10s %s\n","prj:", "creating.. [#{BIT_RESULTFILE} + #{ELF_RESULTFILE}]")
FileUtils.mkdir_p(PRJ_RESULTSDIR) unless File.directory? PRJ_RESULTSDIR
FileUtils.mkdir_p(PRJ_SCRATCHDIR) unless File.directory? PRJ_SCRATCHDIR
logfile = "#{PRJ_SCRATCHDIR}/logfile.txt"
puts %x[(data2mem -bm #{BD_RESULTFILE} -bt #{BIT_RESULTFILE} -bd #{ELF_RESULTFILE} tag #{CPU}  -o b #{PRJ_RESULTFILE} 2>&1) > #{logfile}]
if $?.exitstatus != 0
msg = "#-- \t Error: check '#{logfile}' for details.\n"
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
$stderr.print(msg)
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
puts %x[tail #{logfile}]
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
exit
end
end



# ----------------------- others ----------------------- #

desc "9.Download to the board"
task :dow => :prj do |t|
Rake::Task[:dow!].invoke(nil)
end

task :dow! do |t|
printf("%-10s %s\n","dow:", "downloading..")
IO.popen("impact -batch", "w+") do |pipe|
pipe.puts("setMode -bscan")
pipe.puts("cleancablelock")         # remove cable lock
pipe.puts("setCable -p auto")
pipe.puts("identify")
pipe.puts("assignfile -p 2 -file #{PRJ_RESULTFILE}")
pipe.puts("program -p 2")
pipe.puts("quit")
pipe.close_write
puts pipe.readlines
end
unless $?.exitstatus == 0
logfile = "_impactbatch.log"
msg = "#-- \t Error: check '#{logfile}' for details.\n"
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
$stderr.print(msg)
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
puts %x[tail #{logfile}]
$stderr.print( "#--  " + "-"*msg.size + " --#\n")
exit
end

# clean
FileUtils.rm("etc/download.cmd") if File.exists? "etc/download.cmd"

# move logfiles
FileUtils.mkdir_p(DOW_SCRATCHDIR) unless File.directory? DOW_SCRATCHDIR
FileUtils.mv("_impactbatch.log", "#{DOW_SCRATCHDIR}/") if File.file? "_impactbatch.log"

end


desc "Run xmd"
task :xmd do |t|
%x[xmd -xmp system.xmp -opt etc/xmd_ppc405_0.opt]
end


desc "Todos"
task :todo do |t|
%x[cat todo.txt]
end
