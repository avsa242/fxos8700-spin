# fxos8700-spin 
---------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the NXP FXOS8700 6DoF IMU.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz (with optional alternate slave addresses)
* Read raw accelerometer, magnetometer data output, or scaled (micro-g's, micro-gauss, resp.), scaled temperature (C, F, K)
* Set output data rate
* Set full-scale range (accel only; chip magnetometer is fixed at 1200uT, but retains MagScale() method for API compatibility)
* Flags to indicate data is ready (accel, mag), has overrun (accel, mag)
* Automatically or manually set bias offsets (accel, mag)
* FIFO control and flag reading (set watermark, set circular buffer or FIFO mode, flag if full, number of unread samples)
* Interrupts: specific events (accel; partial support)

## Requirements

P1/SPIN1:
* spin-standard-library

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)
* P2/SPIN2: FastSpin (tested with 4.3.1)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build
* If both accel and mag sensors are enabled, data rate is halved (chip limitation). Currently, the data rate setting methods don't reflect this

## TODO

- [x] Port to P2/SPIN2
- [x] Implement temperature sensor support
- [ ] Implement MagDataRate()

Expand interrupt support:
- [ ] Magnetometer interrupts
- [ ] Pulse detection
- [ ] Free-fall detection
- [ ] Transient detection
