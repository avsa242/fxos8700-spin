{
----------------------------------------------------------------------------------------------------
    Filename:       FXOS8700-IntDemo.spin
    Description:    Demo of the FXOS8700 driver
        * Interrupt functionality
    Author:         Jesse Burt
    Started:        Sep 26, 2020
    Updated:        Jul 10, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    _clkmode    = cfg._clkmode
    _xinfreq    = cfg._xinfreq


' Temperature scales
    C           = 0
    F           = 1


OBJ

    cfg:    "boardcfg.flip"
    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    sensor: "sensor.imu.6dof.fxos8700" | SCL=28, SDA=29, I2C_FREQ=400_000, I2C_ADDR=%11, RST_PIN=-1



PUB main() | i

    setup()
    sensor.preset_active()
    sensor.temp_scale(C)

    sensor.accel_scale(2)                       ' 2, 4, 8 (g's)
    sensor.accel_data_rate(50)                  ' 1, 6, 12, 50, 100, 200, 400, 800
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
        if ( ser.getchar_noblock() == "c" )
            cal_accel()
            cal_mag()

        ser.pos_xy(0, 4)
        show_accel_data()
        ser.printf1(@"Accel int: %08.8b\n\r\n\r", sensor.accel_int())
        show_mag_data()
        ser.printf1(@"Mag int: %03.3b\n\r\n\r", sensor.mag_int())
        show_temp_data()


PUB show_temp_data() | temp, tscl
' Show temperature data
    temp := sensor.temperature()
    tscl := lookupz(sensor.temp_scale(-2): "C", "F")
    ser.printf3(@"Temp. (deg %c): %3.3d.%02.2d\n\r", tscl, (temp / 100), ||(temp // 100))


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( sensor.start() )
        ser.strln(@"FXOS8700 driver started")
    else
        ser.strln(@"FXOS8700 driver failed to start - halting")
        repeat


#include "acceldemo.common.spinh"               ' Use code common to all accelerometer
#include "magdemo.common.spinh"                 '   and magnetometer demos


DAT
{
Copyright 2024 Jesse Burt

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

