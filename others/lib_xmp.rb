#!/usr/bin/env ruby

# This module parses *.xmp file and reads all settings from it.
# This settings are available in space of XMP object.
#
# For example like: 
#  @xmp = XMP_C.new(ARGV[0]);       # parse file
#  p @xmp.DEVICE;
#  @xmp.FOO = BOO;
#
class XMP_c

   # Check if file exists and if it does then parse it
   def initialize (filename)
      if (filename && File::exists?(filename))
         parse (filename)
      else
         fail "xmp file not specified in command line.\nType: '#{$0} <#{XMP_FILE}>'"
      end
   end

   # When method is called which does not exists we print this message
   def method_missing(id, *args)
      # allow only to add methods which end with =
      if id.to_s =~  /=$/
         symbol = id.to_s.chop
         self.class.send(:define_method, symbol ) { args.shift }
      else
         raise "Method '#{id}' '#{args}' is missing"
      end
   end

   # Parse xmp file and look for method -> value. Add method to class. Method returns value.
   #  This is only getter.
   def parse (filename)
      f = File.open(filename)
      f.each do	|line|
         next if line =~ /^#/
         sym, val = line.split(':')
         sym_strip = sym.gsub(/\s+/, "").strip
         val_strip = val.strip
         add_accesor sym_strip, val_strip
      end
      # p "XMP: file parsed"
      f.close
   end

   # Adds method to class. Symbol is the method name and val is value which it will return.
   #  We can call then class.symbol 	# => val
   def add_accesor symbol, val
      # add getter method
      self.class.send(:define_method, symbol) { val }

      # add setter method ( symbol = "value" )
      self.class.send :define_method, symbol<<"=" do |p|
         val=p if p
      end
   end
end

if __FILE__ == $0

   class FOO_c
      def initialize
         @xmp = XMP_c.new(ARGV[0])
         # XMP_c.instance_methods.sort.each { |x| puts x}
      end

      def xmp
         puts "FOO_c: #{@xmp.Device}"
         @xmp    # return
      end

   end

   foo = FOO_c.new
   foo.xmp.Device="abcd"
   puts foo.xmp.Device

end

#vim:tw=78:ts=2:tw=2
