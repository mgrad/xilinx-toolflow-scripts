#!/usr/bin/env ruby

def print_d (string)
   print(string) if DEBUG
end


def checker_and(conditions)
   conditions.each { |cond|
      result = eval("#{cond}")
      print_d(sprintf("%10s: %s\n",result, cond))
      return false unless result
   }
end

def find_xmpfile_location
   here = ENV['PWD']
   Dir.chdir(here)                 # it's different when called from rake, need to initialize that
   while Dir.glob("*.xmp").size == 0 do
      Dir.chdir("..")
      if ENV['PWD'] == here         # if '/' rootdir
         $stderr.puts "Can't locate xmpfile in any path. Please change directory."
         exit
      end
      here = ENV['PWD']
   end
   fn = Dir.glob("*.xmp").first     # only one *xmpfile
   File.expand_path(fn)
ensure
   Dir.chdir(XILMAKE_DIR)
end


if __FILE__ == $0
   XILMAKE_DIR = Dir.pwd
   puts find_xmpfile_location
end
