This project is just to Showcase my love towards **Digital Signal Processing and VLSI** 

My project is all about designing a 5-state finite state machine controller in Verilog. It handles sequencing for the FIR and FFT pipelines.

Created a bit-reversal module. It reorders those 16×16-bit complex samples. The whole process takes just 16 cycles. This serves as preprocessing for the DIT FFT.

Implemented a clock manager featuring divide-by-2 and divide-by-4 options.During idle times for the FIR, FFT, and DMA components, this cuts dynamic power usage by 6 percent.

Block Diagram Of the DSP CHIPLET
![block diagram](https://github.com/user-attachments/assets/f18e8a1e-80da-4e1f-9409-a0fcba72b790)

Result:
<img width="1910" height="1007" alt="output Waveform" src="https://github.com/user-attachments/assets/e32ff236-c41e-486b-8131-732aba007fba" />
