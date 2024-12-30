Verilog code of a FPGA calculator from the assignment of summer semester's EE Production Practice . 
Running on STEP FPGA's (Intel-MAX10) core board and part of the IOs (total is 32) are connected to a designated PCB board.
Simple logic and but could perform operations practically.
The top module is Calculator.v , the function of math operations is defined here. And two functional blocks Keyboard.v and SegDisplay.v constitute the IO realization of this calculator, both recall some other sub modules to fulfill the corresponding duties.
