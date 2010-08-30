# class Bar
#   @@n = 0
#   def initialize
#     @@n += 1
#   end
#   def n
#     @@n
#   end
# end
# 
# class Foo
#   def initialize
#     p "foo: " << Bar.new.n
#   end
# end
# 
# class Trr < Bar
# end
# 
# Foo.new
# p Trr.new.n



# ObjectSpace.each_object(XilMake) { |x|
  # if x.name =~ /XilMake/i
      # p x
      # p x.xmp
      # @xmp = x.xmp
      # p @xmp.Device
      # x.instance_methods.sort.each { |x| puts x}
      # x.new.instance_variables.sort.each {|x| puts x }
  # end
