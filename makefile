# All Targets
all: ass3

# Tool invocations
ass3: ass3.o scheduler.o drone.o target.o printer.o 
	gcc -m32 -Wall -g -o ass3 ass3.o scheduler.o drone.o target.o printer.o

ass3.o: ass3.s
	nasm -f elf -o ass3.o ass3.s

scheduler.o: scheduler.s
	nasm -f elf -o scheduler.o scheduler.s 

drone.o: drone.s
	nasm -f elf -o drone.o drone.s 

target.o: target.s
	nasm -f elf -o target.o target.s 

printer.o: printer.s
	nasm -f elf -o printer.o printer.s 
	
.PHONY: clean

clean: 
	rm -f *.o ass3

# all: ass3

# ass3: ass3.o printer.o 
# 	gcc -m32 -g -Wall -o ass3 ass3.o printer.o 
        
# ass3.o: ass3.s
# 	nasm -g -f elf -w+all -o ass3.o ass3.s

# printer.o: printer.s
# 	nasm -f elf -o printer.o printer.s 

# .PHONY: clean

# clean:
# 	rm -f *.o ass3
