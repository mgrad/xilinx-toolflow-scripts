#!/usr/bin/env ruby

# Zip command for zipped archives.  The default is 'zip'.
# Reads main configuration from EDK project.
#
# Parses *.xmp file (default: system.xmp) from EDK project directory.
#
# Initialize with xmp filename.
#
# Example
#  In system.xmp:
# 	Device: xc12vfxp668
#  In code:
# 	xmp = Read_xmp.new("system.xmp")	# starts parses
#	p xmp.Device		# => xc12vfxp668
class XMP_c
	
	# Check if file exists and if it does then parse it
	def initialize (filename)
		if (filename && File::exists?(filename))
			parse (filename)
		else
			fail "xmp file not specified in command line.\nType: '#{$0} <file.xmp>'"
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
