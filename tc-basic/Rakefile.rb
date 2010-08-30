require 'rake'
require './lib/xilmake.rb'

# import tasks

# Dodajemy metody do XMP_c
# To oznacza, ze mozemy pozniej stworzyc ponownie ten sam obiekt i on juz bedzie mial te metody.
# Rozszerzamy poprostu klase.
# Klasa jest nowa.

# Mozna ja instancjowac kilka razy i za kazdym razem bedzie miala rozszerzone metody.

# 2. Trzeba przemyslec, czy w takim razie potrzebujemy xil.xmp...
# - jesli potrzebny to mozna sobie stworzyc samemu xmp z apomoca XMP_c.new

# 3. Pewnie nie trzeba teraz calej tej hierarchi - dotyczy rowniez xilmake -> hw -> platgen
Rake::XilMake.new do |xil|  
    xil.xmp_file= 'udi/system.xmp'
    xil
    # getting parsed data
    # p xil.xmp.Device
    
    # changing configuration!
    # xil.xmp.Device = "Virtex5"
    # p xil.xmp.Device
      
    # adding new configuration
    # xil.xmp.foo =  "bar"
    # p xil.xmp.foo
          
    # p xil.xmp.test
  end
