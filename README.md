Designed a 5-state finite state machine controller in Verilog. It handles sequencing for the FIR and FFT pipelines. This makes real-time mode switching possible without issues.
Created a bit-reversal module. It reorders those 16×16-bit complex samples. The whole process takes just 16 cycles. This serves as preprocessing for the DIT FFT.
Implemented a clock manager featuring divide-by-2 and divide-by-4 options.During idle times for the FIR, FFT, and DMA components, this cuts dynamic power usage by 6 percent.
