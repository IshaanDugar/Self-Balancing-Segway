# FPGA Self-Balancing Segway

This repository contains the final integrated design for a self-balancing segway implemented entirely in hardware using SystemVerilog on an FPGA. The system contains no embedded software, no firmware, and no processor. All sensing, control, safety, and actuation logic runs directly in synthesizable hardware.

This README served as the primary reference for full-system integration, testing, and synthesis.

---

## System Overview

The design implements a real-time control system that stabilizes a two-wheeled segway platform while supporting steering, rider authentication, and safety handling. Sensor data is acquired from an IMU and ADC, processed through fixed-point control logic, and converted into motor PWM outputs.

Major subsystems:

- Inertial sensing and ADC interfaces
- Fixed-point PID balance controller
- Steering and differential motor control
- PWM motor drivers with current protection
- UART-based Bluetooth authentication
- Safety and fault-handling logic

The entire system was synthesized to run at 125 MHz and verified using ModelSim with custom testbenches and a physics-based segway model.

---

## Hardware Architecture

### Sensors and Interfaces

- IMU connected via SPI for pitch and angular rate measurements
- ADC connected via SPI for load cell inputs, battery voltage, and steering potentiometer
- UART interface for Bluetooth-based command and authentication handling

All interfaces are fully synchronous and designed for deterministic timing behavior.

### Balance Controller

- Fixed-point PID controller implemented in SystemVerilog
- Fully pipelined to meet timing at high clock frequencies
- Tuned to stabilize platform pitch around zero under rider disturbances
- Designed to tolerate additional latency introduced by pipelining

### Motor Control

- PWM generation for left and right motors
- Differential steering logic adjusts motor speeds based on steering input
- Soft-start logic ramps motor output to prevent sudden motion
- Over-current detection triggers immediate motor shutdown

### Safety Logic

- Rider detection using load cell thresholds
- Emergency shutdown on fault or over-current conditions
- Authentication gate prevents activation without valid Bluetooth command
- Safe disable state ensures motors are inactive on reset or error

---

## Top-Level Integration

The top-level module integrates all subsystems into a single synchronous design. Control flow is entirely hardware-driven, with clear separation between sensing, control, and actuation stages.

The system supports the following high-level states:

- Idle and disabled state
- Authentication and enable sequence
- Active balance and steering control
- Fault and emergency shutdown

---

## Verification Strategy

Verification was performed using ModelSim with a layered testbench architecture.

### Testbench Components

- UART command generator to simulate enable and stop commands
- SPI models for IMU and ADC behavior
- Physics-based segway model that reacts to PWM outputs and generates inertial feedback
- Self-checking tasks for stimulus application and response validation

### Testing Approach

- Step-response testing of rider lean input to validate PID stability
- Verification of convergence of platform pitch back to zero
- Steering input tests to confirm differential motor behavior
- Safety tests including rider removal and over-current conditions

Long-running simulations were accelerated using a fast_sim parameter to shorten internal timers while preserving functional behavior.

---

## Synthesis

The design was synthesized at the full segway top level with area as the primary optimization goal.

Key synthesis considerations:

- Pipelining added along long arithmetic paths in the balance controller
- Multicycle constraints applied to inertial sensor data paths
- Hierarchy flattened before final area reporting
- Post-synthesis gate-level simulation performed to validate basic functionality

The final design met timing requirements and maintained functional correctness after synthesis.

---

## Notes

This project emphasizes deterministic real-time control, hardware-only system design, and rigorous verification. It was developed as a team effort, with individual contributions spanning control logic, sensor interfaces, motor drivers, and system integration. The simulation can be done on any software that can compile and run SystemVerilog files, in our case, it was ModelSim.# \# FPGA Self-Balancing Segway

# 

# This repository contains the final integrated design for a self-balancing segway implemented entirely in hardware using SystemVerilog on an FPGA. The system contains no embedded software, no firmware, and no processor. All sensing, control, safety, and actuation logic runs directly in synthesizable hardware.

# 

# This README served as the primary reference for full-system integration, testing, and synthesis.

# 

# ---

# 

# \## System Overview

# 

# The design implements a real-time control system that stabilizes a two-wheeled segway platform while supporting steering, rider authentication, and safety handling. Sensor data is acquired from an IMU and ADC, processed through fixed-point control logic, and converted into motor PWM outputs.

# 

# Major subsystems:

# 

# \* Inertial sensing and ADC interfaces

# \* Fixed-point PID balance controller

# \* Steering and differential motor control

# \* PWM motor drivers with current protection

# \* UART-based Bluetooth authentication

# \* Safety and fault-handling logic

# 

# The entire system was synthesized to run at 125 MHz and verified using ModelSim with custom testbenches and a physics-based segway model.

# 

# ---

# 

# \## Hardware Architecture

# 

# \### Sensors and Interfaces

# 

# \* IMU connected via SPI for pitch and angular rate measurements

# \* ADC connected via SPI for load cell inputs, battery voltage, and steering potentiometer

# \* UART interface for Bluetooth-based command and authentication handling

# 

# All interfaces are fully synchronous and designed for deterministic timing behavior.

# 

# \### Balance Controller

# 

# \* Fixed-point PID controller implemented in SystemVerilog

# \* Fully pipelined to meet timing at high clock frequencies

# \* Tuned to stabilize platform pitch around zero under rider disturbances

# \* Designed to tolerate additional latency introduced by pipelining

# 

# \### Motor Control

# 

# \* PWM generation for left and right motors

# \* Differential steering logic adjusts motor speeds based on steering input

# \* Soft-start logic ramps motor output to prevent sudden motion
# FPGA Self-Balancing Segway

This repository contains the final integrated design for a self-balancing segway implemented entirely in hardware using SystemVerilog on an FPGA. The system contains no embedded software, no firmware, and no processor. All sensing, control, safety, and actuation logic runs directly in synthesizable hardware.

This README served as the primary reference for full-system integration, testing, and synthesis.

---

## System Overview

The design implements a real-time control system that stabilizes a two-wheeled segway platform while supporting steering, rider authentication, and safety handling. Sensor data is acquired from an IMU and ADC, processed through fixed-point control logic, and converted into motor PWM outputs.

Major subsystems:

- Inertial sensing and ADC interfaces
- Fixed-point PID balance controller
- Steering and differential motor control
- PWM motor drivers with current protection
- UART-based Bluetooth authentication
- Safety and fault-handling logic

The entire system was synthesized to run at 125 MHz and verified using ModelSim with custom testbenches and a physics-based segway model.

---

## Hardware Architecture

### Sensors and Interfaces

- IMU connected via SPI for pitch and angular rate measurements
- ADC connected via SPI for load cell inputs, battery voltage, and steering potentiometer
- UART interface for Bluetooth-based command and authentication handling

All interfaces are fully synchronous and designed for deterministic timing behavior.

### Balance Controller

- Fixed-point PID controller implemented in SystemVerilog
- Fully pipelined to meet timing at high clock frequencies
- Tuned to stabilize platform pitch around zero under rider disturbances
- Designed to tolerate additional latency introduced by pipelining

### Motor Control

- PWM generation for left and right motors
- Differential steering logic adjusts motor speeds based on steering input
- Soft-start logic ramps motor output to prevent sudden motion
- Over-current detection triggers immediate motor shutdown

### Safety Logic

- Rider detection using load cell thresholds
- Emergency shutdown on fault or over-current conditions
- Authentication gate prevents activation without valid Bluetooth command
- Safe disable state ensures motors are inactive on reset or error

---

## Top-Level Integration

The top-level module integrates all subsystems into a single synchronous design. Control flow is entirely hardware-driven, with clear separation between sensing, control, and actuation stages.

The system supports the following high-level states:

- Idle and disabled state
- Authentication and enable sequence
- Active balance and steering control
- Fault and emergency shutdown

---

## Verification Strategy

Verification was performed using ModelSim with a layered testbench architecture.

### Testbench Components

- UART command generator to simulate enable and stop commands
- SPI models for IMU and ADC behavior
- Physics-based segway model that reacts to PWM outputs and generates inertial feedback
- Self-checking tasks for stimulus application and response validation

### Testing Approach

- Step-response testing of rider lean input to validate PID stability
- Verification of convergence of platform pitch back to zero
- Steering input tests to confirm differential motor behavior
- Safety tests including rider removal and over-current conditions

Long-running simulations were accelerated using a fast_sim parameter to shorten internal timers while preserving functional behavior.

---

## Synthesis

The design was synthesized at the full segway top level with area as the primary optimization goal.

Key synthesis considerations:

- Pipelining added along long arithmetic paths in the balance controller
- Multicycle constraints applied to inertial sensor data paths
- Hierarchy flattened before final area reporting
- Post-synthesis gate-level simulation performed to validate basic functionality

The final design met timing requirements and maintained functional correctness after synthesis.

---

## Notes

This project emphasizes deterministic real-time control, hardware-only system design, and rigorous verification. It was developed as a team effort, with individual contributions spanning control logic, sensor interfaces, motor drivers, and system integration. The simulation can be done on any software that can compile and run SystemVerilog files, in our case, it was ModelSim.
# \* Post-synthesis gate-level simulation performed to validate basic functionality


