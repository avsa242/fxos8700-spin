{
    --------------------------------------------
    Filename: FXOS8700-IntDemo.spin
    Author: Jesse Burt
    Description: Demo of the FXOS8700 driver
        * Interrupt functionality
    Copyright (c) 2022
    Started Sep 26, 2020
    Updated Nov 7, 2022
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

    cfg : "boardcfg.flip"
    ser : "com.serial.terminal.ansi"
    time: "time"
    sensor : "sensor.imu.6dof.fxos8700"

PUB main{} | i

    setup{}
    sensor.preset_active{}
    sensor.temp_scale(C)

    sensor.accel_scale(2)                   ' 2, 4, 8 (g's)
    sensor.accel_data_rate(50)               ' 1, 6, 12, 50, 100, 200, 400, 800
    sensor.accel_int_mask(%11111111)

    { set up magnetometer interrupts; 0..32_767000 microGauss thresholds }
    { *NOTE: The chip doesn't account for bias offsets when comparing the set thresholds to the
        measurement data. They are compared to the uncorrected data only. }
    sensor.mag_int_duration(0)
    sensor.mag_int_set_thresh_x(1_000000)
    sensor.mag_int_set_thresh_y(1_000000)
    sensor.mag_int_set_thresh_z(1_000000)

    sensor.mag_int_ena(true)
    sensor.mag_int_mask(%111)

    ser.pos_xy(0, 3)
    repeat i from 0 to 2
        ser.pos_x(12+(16*i))
        ser.putchar(i+"X")

    repeat
        if (ser.rx_check{} == "c")
            cal_accel{}
            cal_mag{}

        ser.pos_xy(0, 4)
        show_accel_data{}
        ser.printf1(string("Accel int: %08.8b\n\r\n\r"), sensor.accel_int{})
        show_mag_data{}
        ser.printf1(string("Mag int: %03.3b\n\r\n\r"), sensor.mag_int{})
        show_temp_data{}

PUB show_temp_data{} | temp, tscl
' Show temperature data
    temp := sensor.temperature{}
    tscl := lookupz(sensor.temp_scale(-2): "C", "F")
    ser.printf3(string("Temp. (deg %c): %3.3d.%02.2d\n\r"), tscl, (temp / 100), ||(temp // 100))

PUB setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if sensor.startx(I2C_SCL, I2C_SDA, I2C_FREQ, ADDR_BITS, RES_PIN)
        ser.strln(string("FXOS8700 driver started"))
    else
        ser.strln(string("FXOS8700 driver failed to start - halting"))
        repeat

#include "acceldemo.common.spinh"
#include "magdemo.common.spinh"

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

