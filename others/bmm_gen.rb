#!/usr/bin/env ruby
# $Revision: 1.2 $
# $Date: 2007-03-01 21:41:46 $
# my_name < email@example.com >
#
# DESCRIPTION:
# USAGE:
# LICENSE: ___

h = Hash.new()

File.open("static_full.bitgen").each { |line|
   if (line =~ /'(plb.*)'.*'RAMB16_(X\d+Y\d+)/)
      h[$1] = $2;
      # puts "Read: " << $1  << " " << $2
   end
}

File.open("../system.bmm").each { |line|
   if (line =~ /^\s+(plb.*)\s+(.*) ;/)
      if h.include?($1)
         puts "\t\t#{$1} #{$2} PLACED = #{h.fetch($1)};"
      else
         puts "ERROR !!! Physical BRAM for #{$1} not found"
         exit(1)
      end

   else 
      puts line
   end
   
}
