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
def move_files_if(src_files, dst_dir)
   dst_dir << "/" unless dst_dir =~ /\/$/
   Dir[src_files].each do |srcfile|
      cp_action = 0
      dstfile = "#{dst_dir}#{File.basename(srcfile)}"


      # check if exists similar one in hdl/ directory
      if !File.file? dstfile
         cp_action = 1
         # if exists but differs
      elsif !FileUtils.identical?(dstfile, srcfile) then

         print "File '#{dstfile}' exists and differs from generated one. Overwrite? [Y/N] "
         if $stdin.gets =~ /y/i
            cp_action = 2
         end
      end

      if cp_action > 0
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
   File.symlink("../pcores", "#{TMPDIR}/pcores") unless File.symlink?("#{TMPDIR}/pcores")
   pipe = IO.popen("platgen -od #{TMPDIR}/ -p xc4vfx12ff668-10 -lang vhdl ../system.mhs", "r+")
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
      p "# Error"
      exit
   end

   # he generated files under $PROJECT/TMPDIR/{hdl,synthesis}
   # copy them to $PROJECT/hdl/ under certain conditions (size differs & or abstence)
   FileUtils.mkdir('hdl') unless File.directory? 'hdl'
   FileUtils.mkdir('synthesis') unless File.directory? 'synthesis'
   FileUtils.mkdir_p(BMM_RESULTSDIR) unless File.directory? BMM_RESULTSDIR # output directory

   move_files_if("#{TMPDIR}/hdl/*.vhd", "hdl/")
   move_files_if("#{TMPDIR}/implementation/#{TOPLEVEL}.bmm", BMM_RESULTSDIR)
   move_files_if("#{TMPDIR}/synthesis/*.scr", "synthesis/")
   move_files_if("#{TMPDIR}/synthesis/*.prj", "synthesis/")

   # move logfiles to scratch
   FileUtils.mkdir_p(GEN_SCRATCHDIR) unless File.directory? GEN_SCRATCHDIR
   ["platgen.log", "platgen.opt", "#{TMPDIR}/clock_generator*.log"].each { |t|
      FileUtils.mv(t, "#{GEN_SCRATCHDIR}/") if File.file? t
   }

end




# ----------------------- creating synthesis tasks ----------------------- #
# it's responsed for executing synthesis command and wrapping errors
def synthesis_cmd (component, scrfile)
   Dir.chdir('synthesis')
   printf("%10s %s\n","synthesis:", component)
   FileUtils.mkdir_p(NGC_SCRATCHDIR) unless File.directory? NGC_SCRATCHDIR
   logfile =  "#{NGC_SCRATCHDIR}/#{component}_xst.srp"
   cmd = %Q[xst -ifn #{scrfile} -ofn #{logfile} -intstyle silent]
   # p cmd
   %x[#{cmd}]
   # sh %Q[xst -ifn #{scrfile}  -intstyle ise]
   if $?.exitstatus != 0
      msg = "#-- \t Error: check '#{logfile}' for details.\n"
      $stderr.print( "#--  " + "-"*msg.size + " --#\n")
      $stderr.print(msg)
      $stderr.print( "#--  " + "-"*msg.size + " --#\n")
      puts %x[tail #{logfile}]
      $stderr.print( "#--  " + "-"*msg.size + " --#\n")
      exit
   end
   Dir.chdir('..')

   # move results to NGC_RESULTSDIR
   FileUtils.mkdir_p(NGC_RESULTSDIR) unless File.directory? NGC_RESULTSDIR
   ngcfile = "implementation/#{component}.ngc"
   FileUtils.mv(ngcfile, "#{NGC_RESULTSDIR}/") if File.file? ngcfile

   # remove xst temporary dir
   FileUtils.rm_rf("synthesis/xst") if File.directory? "synthesis/xst"
end


# input: prj source file
# output: array with dependency filenames
def parse_prjfile(src)
   result = Array.new
   File.open(src).each  { |line|
      line =~ /(\S+)$/
      file = $1
      file.gsub!(/\.\.\//, '')
      result.push(file)
   }
   result
end

# generates synthesis task for each component
def create_synthesis_tasks
   # Create filelist with vhd files
   hdlfiles = Dir["hdl/*.vhd"].delete_if { |x|
      x =~ /#{EXCLUDE_HDL}/
   }

   # create synthesise task for each (vhdfile) component
   ngcfiles = Array.new    # implementation/*.ngc
   scrfiles = Array.new    # synthesis/*.scr
   prjfiles = Array.new    # synthesis/*.prj
   hdlfiles.each { |vhdfile|
      component = vhdfile.gsub(/^hdl\/|.vhd$/,'')
      ngcfile = "#{NGC_RESULTSDIR}/#{component}.ngc"
      scrfile = "#{component}_xst.scr"
      prjfile = "#{component}_xst.prj"
      full_scrfile = "synthesis/#{scrfile}"
      full_prjfile = "synthesis/#{prjfile}"
      ngcfiles.push(ngcfile)                    # store for later
      scrfiles.push(scrfile)                    # store for later
      prjfiles.push(prjfile)                    # store for later

      # create synthesis task for each component
      unless Rake::Task.task_defined? ngcfile
         # p "adding task: #{component}"
         prj_deps = parse_prjfile(full_prjfile)
         file ngcfile => [vhdfile, full_scrfile, full_prjfile, prj_deps].flatten! do
            synthesis_cmd(component, scrfile) 
         end

         # check dependencies - they should exists
         [full_scrfile, full_prjfile, prj_deps].flatten!.each { |dep_src|
            file dep_src do
               $stderr.print "Error:\n" \
               "\tDon't know how to synthesis '#{vhdfile}'.\n" \
               "\t'#{full_scrfile}' is missing.\n"
               exit;
            end
         }
      end
   }

   # add all components as dependencies
   # this is main synthesis task
   ngcfiles.delete(NGC_RESULTFILE)
   file NGC_RESULTFILE => ngcfiles

end



# -----------------------  ngdbuild ----------------------- #
# dependencies for BMM file
file BMM_RESULTFILE => "#{TMPDIR}/implementation/#{TOPLEVEL}.bmm" do |t|
   FileUtils.cp t.prerequisites[-1], t.name
end

# always executed because of dependencies
file "#{TMPDIR}/implementation/#{TOPLEVEL}.bmm" => :generator do |t|

end
