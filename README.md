# *FPGA-NHAP: Neuromorphic Hardware Acceleration Platform*

> *Copyright (C) 2020-2022, Guangdong University of Technology, Guangzhou*

> *Digital HDL source code of FPGA-NHAP is free: you can redistribute it and/or modify it under the terms of the Solderpad Hardware License v2.0, which extends the Apache v2.0 license for hardware use.*

> *The software, hardware and materials distributed under this license are provided in the hope that it will be useful on an **'as is' basis, without warranties or conditions of any kind, either expressed or implied; without even the implied warranty of merchantability or fitness for a particular purpose**. See the Solderpad Hardware License for more details.*

> *You should have received a copy of the Solderpad Hardware License along with the ODIN HDL files (see [LICENSE](LICENSE) file). If not, see <https://solderpad.org/licenses/SHL-2.0/>.*

FPGA-NHAP is general **FPGA-** based **n**euromorphic **h**ardware **a**cceleration **p**latform,  supporting the effective inference and acceleration of SNN network with low power, high speed and good scalability. The key features of our FPGA-NHAP are as follows.

**(a)** a neuron computing unit is designed to simulate the both **LIF** and **Izhikevich (IZH)** neurons with the parallel spike caching and scheduling technique. 

**(b)** a **novel integrated driven update algorithm** is proposed to complete the spike encoding of external data, reducing the waiting time of neuron state update effectively. 

**(c)** the proposed platform is implemented using a **RISC-V processor** and a Xilinx FPGA, simulating **16,384** neurons and **16.8 million** synapses with a power consumption of **0.535 W**.

In case you decide to use the FPGA-NHAP HDL source code for academic or commercial use, we would appreciate if you let us know; **feedback is welcome**. Upon usage of the source code, please cite the associated paper (also available [here](https://doi.org/10.1109/TCSI.2022.3160693)):

> Y. Liu, Y. Chen, W. Ye and Y. Gui, "FPGA-NHAP: A General FPGA-Based Neuromorphic Hardware Acceleration Platform With High Speed and Low Power," in IEEE Transactions on Circuits and Systems I: Regular Papers, vol. 69, no. 6, pp. 2553-2566, 2022.