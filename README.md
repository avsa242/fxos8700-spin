# fxos8700-spin 
---------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the NXP FXOS8700 6DoF IMU.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Supports default or alternate I2C address
* Manually or automatically set bias offsets (on-chip)
* Accelerometer built-in self-test
* Read accelerometer data in ADC words or micro-g's
* Read magnetometer data in ADC words or micro-Gauss
* Read temperature (C, F, K)
* Set output data rate (accel+mag locked, in active and low-power operating modes)
* Set power state
* Set accelerometer full-scale
* Set interrupt flags, INT1/2 pin active state
* Set accelerometer data oversampling/power mode (in active and low-power operating modes)
* Output data filtering: high-pass
* Read flags: data ready (accel, mag), data overrun (accel, mag), interrupts
* Orientation detection
* Click/Pulse/Tap detection
* Free-fall detection
* Inactivity detection/auto-sleep
* FIFO control and flag reading (set watermark, set circular buffer or FIFO mode, flag if full, number of unread samples)

## Requirements

P1/SPIN1:
* spin-standard-library
* 1 extra core/cog for the PASM I2C engine

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1 OpenSpin (bytecode): OK, tested with 1.00.81
* P1/SPIN1 FlexSpin (bytecode): OK, tested with 5.9.4-beta
* P1/SPIN1 FlexSpin (native): OK, tested with 5.9.4-beta
* ~~P2/SPIN2 FlexSpin (bytecode): FTBFS, tested with 5.9.4-beta~~
* P2/SPIN2 FlexSpin (native): OK, tested with 5.9.4-beta
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* If both accel and mag sensors are enabled, data rate is halved (chip limitation). Currently, the data rate setting methods don't reflect this

