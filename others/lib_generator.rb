# IDEAS todo:
#     = 1. automatically backup diffs between vhd files
#     = 2. synthesis cache
#     = 3. ngcbuild (apply ucf) to components which need that (not all of them)
#        - not true (ucf) is not used with all components
#     = 4. make possible to change synthesis/ hdl/ implementation/ directory names
#     = 6. each stage generates more than only result file. Make dependencies to these files.
#        = analyze | parse logfiles
#     = 7. analyze changes in vhd file and rebuild only if neccessary (not when names change or whitechar)
#     = 8. Replace ngc main xst task with multitask (parallelism)
#     = 9. Show nice rake -T (in tree form or categorized list)
#     = 10. Customize output -debug (choose %x, sh - or just show runned command)
#     = 11. Make task which makes possible to show logs from last build (store logfile)
#     = 12. check if bus macros were used in logfiles (parsing logfiles)
#     = 13. Work more on xst and parameters (plb_bram & pcore(apu_wool))
#     = 14. Get ngcfile by parsing scrfile (or generate scrfile onthe fly)
#
#     = 15. Add busmacro library to synthesis/system_xst.prj
#
#     = 16. After adding/removing component under XPS merge automatically system.vhd files
#         - hard!
#     = 17. change synthesis/*prj to relative ones
#     = 18. parse srp (xst) output files for unconnected signals !!!
#     = 19. start using guided mapping in 'map' process (really easy but saves a lot of time)
#
#     = 20. control quality of design (normaly work with lowest optimizations / allow different)
#     = 21. when busmacros detected then switch map process automatically to -u
#
#     = 22. when module is black boxed in system.vhd then do not resynthesize system.vhd
#     = 23. parse *prj when generator and check paths if file exists
#     = 24. import project - when there are generated *ngc *ngd files etc just fetch them
#     = 25. use diff -y when there are difference with generator
#     = 26. have merge mode where you can change timestamps of files when task is not needed
#         - for example when you cp -rf _xilmake/hdl/* hdl/* ?
#
#
#     = 27. after running generator link all *edn *ngc files from _xilmake/implementation/*wrappers/*
#     = 28. when generator is running it changes files in _xilmake/hdl/elaborate and these are newer
#           than *.ngc file = rebuild ngc task also synthesis/*lso files are then newer
#
#     = 29! We need generator which will recursivly browse thru _xilmake, compare files, check if there is too
#           of them in DESIGN dir or less, make compact wyrownanie & compare timestamps!!!
#           - rozroznic kiedy ma byc uruchomiony generator a kiedy tylko wyrownanie!
#
#
#     par -gf previous_run.ncd -gm leverage design_ncd place_and_routed.ncd design.pcf
#     par -gf previous_run_NCD -gm incremental design.ncd new_design.ncd design.pcf
#
#
# ----------------------- creating makefiles ----------------------- #

def makefile_generator
   printf("%-10s %s\n","makefile:", "generating..")
   IO.popen("xps -nw", "w+") do |pipe|
      pipe.puts "xload xmp system.xmp"
      pipe.puts "save make"
      pipe.puts "exit"
      pipe.close_write
      output = pipe.readlines
      output.delete_if { |x| x !~ /^XPS/ or x =~ /^XPS% 0/}
      output.each {|x| printf("%10s %s", "","#{x.sub!(/^XPS% /, '')}")}
      # pipe.read
   end
   unless $?.exitstatus == 0
      p "# Error"
      exit
   end

   FileUtils.mkdir_p(MAK_SCRATCHDIR) unless File.directory? MAK_SCRATCHDIR
   FileUtils.mv("system.log", "#{MAK_SCRATCHDIR}/") if File.file? "system.log"
end




# ----------------------- creating hdls, bmm, scr, prj ----------------------- #
# moves files between directories if they differ or don't exists
def move_files_if(src_files, dst_dir = nil)
   Dir[src_files].each do |srcfile|
      cp_action = 0
      dst_dir = File.dirname(src_files).gsub(TMPDIR, '').gsub(/^\//, '') if dst_dir == nil
      dst_dir << "/" unless dst_dir =~ /\/$/
      dstfile = "#{dst_dir}#{File.basename(srcfile)}"

      # check if exists similar one in hdl/ directory
      if !File.file? dstfile
         cp_action = 1
         # if exists but differs
      elsif !FileUtils.identical?(dstfile, srcfile) then
         
         puts "-" * 43 << "existing one" << "-" * 44   << '|' << "-" * 44 << "generated" << "-" * 43 << "\n" 
         puts %x{diff -y -W200 #{dstfile} #{srcfile} | less }
         puts "-" * 200
         print "Use generated file #{File.basename(srcfile)}?  [Y/N] "
         if $stdin.gets =~ /y/i
            cp_action = 2
         end
      end
      if cp_action > 0
         FileUtils.mkdir_p(dst_dir) unless File.directory? dst_dir
         FileUtils.cp srcfile, dstfile
         if cp_action == 1
            printf("%5s %20s %s\n","", " new file added:", dstfile)
         else
            printf("%20s %s\n"," overwrited:", dstfile)
         end
      end
   end
end

# generate hdl, bmm, scr, prj under TMPDIR and move them to project dir if necessary
def generator
   printf("%-10s %s\n","generator:", "generating.. (*hdls, *bmm, *scr, *prj)")
   exitcode = 1
   FileUtils.rm_r Dir.glob("#{TMPDIR}/hdl/*.vhd")
   FileUtils.rm_r Dir.glob("#{TMPDIR}/synthesis/*.vhd")
   File.symlink("../pcores", "#{TMPDIR}/pcores") unless File.symlink?("#{TMPDIR}/pcores")
   pipe = IO.popen("platgen -od #{TMPDIR}/ -p xc4vfx100ff1152-10 -lang vhdl ../system.mhs", "r+")
   # pipe = IO.popen("platgen -p xc4vfx12ff668-10 system.mhs", "r+")
   pipe.each do |line|
      # puts line
      # do not synthesize
      if  line =~ /Running XST synthesis/
         exitcode = 0
         Process.kill 'TERM', pipe.pid
         break
      end
   end
   unless exitcode == 0
      p "# Error with platgen - check platgen.log"
      exit
   end

   # he generated files under $PROJECT/TMPDIR/{hdl,synthesis}
   # copy them to $PROJECT/hdl/ under certain conditions (size differs & or abstence)
   FileUtils.mkdir('hdl') unless File.directory? 'hdl'
   FileUtils.mkdir('synthesis') unless File.directory? 'synthesis'
   FileUtils.mkdir_p(BMM_RESULTSDIR) unless File.directory? BMM_RESULTSDIR # output directory

   # move_files_if("#{TMPDIR}/hdl/*.vhd")
   move_files_if("#{TMPDIR}/implementation/#{TOPLEVEL}.bmm", BMM_RESULTSDIR)
   move_files_if("#{TMPDIR}/synthesis/*.scr" )
   move_files_if("#{TMPDIR}/synthesis/*.prj")
   Find.find("#{TMPDIR}/hdl") do |path|
      move_files_if(path) if File.file? path
   end

   # move logfiles to scratch
   FileUtils.mkdir_p(GEN_SCRATCHDIR) unless File.directory? GEN_SCRATCHDIR
   ["platgen.log", "platgen.opt", "#{TMPDIR}/clock_generator*.log"].each { |t|
      FileUtils.mv(t, "#{GEN_SCRATCHDIR}/") if File.file? t
   }

   # change timestamps

end





# -----------------------  ngdbuild ----------------------- #
# dependencies for BMM file
file BMM_RESULTFILE => "#{TMPDIR}/implementation/#{TOPLEVEL}.bmm" do |t|
   FileUtils.cp t.prerequisites[-1], t.name
end

# always executed because of dependencies
file "#{TMPDIR}/implementation/#{TOPLEVEL}.bmm" => :generator do |t|

end
