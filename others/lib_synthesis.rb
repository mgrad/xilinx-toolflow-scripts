#!/usr/bin/env ruby
# $Revision: 1.2 $
# $Date: 2007-03-01 21:41:46 $
# my_name < email@example.com >
#
# DESCRIPTION:
# USAGE:
# LICENSE: ___



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
      line =~ /(\S+)$/  # get filename
      file = $1
      file.gsub!(/\.\.\//, '')
      file.gsub!(/^#{TMPDIR}\//, '') # remove tmpdir from the string if exists (such as in case of elaborate)
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
      full_scrfile = "#{DESIGN_DIR}/synthesis/#{scrfile}"
      full_prjfile = "#{DESIGN_DIR}/synthesis/#{prjfile}"
      ngcfiles.push(ngcfile)                    # store for later
      scrfiles.push(scrfile)                    # store for later
      prjfiles.push(prjfile)                    # store for later

      # create synthesis task for each component
      unless Rake::Task.task_defined? ngcfile
         # p "adding task: #{component}"
         prj_deps = parse_prjfile(full_prjfile)
         file ngcfile => [vhdfile, full_scrfile, full_prjfile, prj_deps].flatten! do |t|
            puts t.investigation() if DEBUG
            synthesis_cmd(component, scrfile)
         end

         # check dependencies - they should exists
         # [full_scrfile, full_prjfile, prj_deps].flatten!.each { |dep_src|
         #   file dep_src do      # it will execute if there is no such file
         #      $stderr.print "Error:\n" \
         #      "\tDon't know how to synthesis '#{vhdfile}'.\n" \
         #      "\t'#{full_scrfile}' is missing.\n"
         #      exit;
         #   end
      # }
      end
   }

   # add all components as dependencies
   # this is main synthesis task
   ngcfiles.delete(NGC_RESULTFILE)
   file NGC_RESULTFILE => ngcfiles

end


