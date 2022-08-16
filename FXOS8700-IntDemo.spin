{
    --------------------------------------------
    Filename: FXOS8700-IntDemo.spin
    Author: Jesse Burt
    Description: Demo of the FXOS8700 driver
        Interrupt functionality
    Copyright (c) 2022
    Started Sep 26, 2020
    Updated Aug 16, 2022
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    LED         = cfg#LED1
    SER_BAUD    = 115_200

    { I2C configuration }
    I2C_SCL     = 28
    I2C_SDA     = 29
    I2C_FREQ    = 400_000
    ADDR_BITS   = %11                           ' %00..%11 ($1E, 1D, 1C, 1F)

    RES_PIN     = -1                            ' reset optional: -1 to disable
' --

' Temperature scales
    C           = 0
    F           = 1

OBJ

    cfg : "core.con.boardcfg.flip"      ' Clock setup, I/O pins, etc
    ser : "com.serial.terminal.ansi"
    time: "time"
    imu : "sensor.imu.6dof.fxos8700"

PUB main{} | i

    setup{}
    imu.preset_active{}
    imu.tempscale(C)

    imu.accelscale(2)                   ' 2, 4, 8 (g's)
    imu.acceldatarate(50)               ' 1, 6, 12, 50, 100, 200, 400, 800
    imu.intmask(%11111111)

    { set up magnetometer interrupts }
    imu.magintpersistence(0)
    imu.magintthreshx(1_000000)         '\  thresholds
    imu.magintthreshy(1_000000)         ' - 0..32_767000 (microGauss, unsigned)
    imu.magintthreshz(1_000000)         '/
                                        ' *NOTE: The chip doesn't account for
                                        ' bias offsets when comparing the
                                        ' set thresholds to the measurement
                                        ' data. They are compared to the
                                        ' uncorrected data only.
    imu.magthreshintsenabled(true)
    imu.magthreshintmask(%111)

    ser.position(0, 3)
    repeat i from 0 to 2
        ser.positionx(12+(16*i))
        ser.char(i+"X")

    repeat
        if (ser.rxcheck{} == "c")
            calibrate{}

        ser.position(0, 4)
        acceldata{}
        ser.printf1(string("Accel int: %08.8b\n\r\n\r"), imu.interrupt{})
        magdata{}
        ser.printf1(string("Mag int: %03.3b\n\r\n\r"), imu.magint{})
        tempdata{}

PUB tempdata{} | temp, tscl
' Show temperature data
    temp := imu.temperature{}
    tscl := lookupz(imu.tempscale(-2): "C", "F")
    ser.printf3(string("Temp. (deg %c): %3.3d.%02.2d\n\r"), tscl, (temp / 100), ||(temp // 100))

PUB setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if imu.startx(I2C_SCL, I2C_SDA, I2C_FREQ, ADDR_BITS, RES_PIN)
        ser.strln(string("FXOS8700 driver started"))
    else
        ser.strln(string("FXOS8700 driver failed to start - halting"))
        repeat

#include "imudemo.common.spinh"                 ' use common IMU demo code for sensor display

DAT
{
Copyright 2022 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

