{
----------------------------------------------------------------------------------------------------
    Filename:       FXOS8700-AutoSleepDemo.spin
    Description:    Demo of the FXOS8700 driver
        * Auto-sleep functionality
    Author:         Jesse Burt
    Started:        Nov 6, 2021
    Updated:        May 31, 2025
    Copyright (c) 2025 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    _clkmode    = xtal1+pll16x
    _xinfreq    = 5_000_000

' -- User-modifiable constants
    LED         = 26
    INT1        = 24                            ' FXOS8700 INT1 pin
' --


OBJ

    time:   "time"
    sensor: "sensor.imu.6dof.fxos8700" | SCL=28, SDA=29, I2C_FREQ=400_000, I2C_ADDR=%11, RST_PIN=-1
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200


VAR

    long _isr_stack[50]                         ' stack for ISR core
    long _intflag                               ' interrupt flag


PUB main() | intsource, temp, sysmod, a[3]

    setup()
    sensor.preset_active()                      ' default settings, but enable sensor power,
                                                ' and set scale factors
    sensor.accel_int_polarity(sensor.LOW)
    sensor.accel_data_rate(100)                 ' 100Hz ODR when active
    sensor.auto_sleep_ena(true)                 ' enable auto-sleep
    sensor.accel_sleep_pwr_mode(sensor.LOPWR)   ' lo-power mode when sleeping
    sensor.accel_pwr_mode(sensor.HIGHRES)       ' high-res mode when awake
    sensor.trans_axis_ena(%011)                 ' transient detection on X, Y
    sensor.trans_thresh(0_252000)               ' set thresh to 0.252g (0..8g)
    sensor.trans_set_cnt(1)                     ' reset counter
    sensor.inact_set_time(5_120)                ' inactivity timeout ~5sec
    sensor.inact_int(sensor.WAKE_TRANS)         ' wake on transient accel
    sensor.accel_int_mask(sensor.INT_AUTOSLPWAKE | sensor.INT_TRANS)
    sensor.accel_int_routing(sensor.INT_AUTOSLPWAKE | sensor.INT_TRANS)
    sensor.auto_sleep_data_rate(6)              ' 6Hz ODR when sleeping
    dira[LED] := 1

    ' The demo continuously displays the current accelerometer data.
    ' When the sensor goes to sleep after approx. 5 seconds, the change
    '   in data rate is visible as a slowed update of the display.
    ' To wake the sensor, shake it along the X and/or Y axes
    '   by at least the amount set in trans_thresh() above.
    ' When the sensor is awake, the LED should be on.
    ' When the sensor goes to sleep, it should turn off.
    repeat
        ser.pos_xy(0, 3)
        repeat
        until sensor.accel_data_rdy()           ' wait for new accel/gyro data

        ' copy accelerometer data (micro-g's) to an array here
        sensor.accel_g(@a[sensor.X_AXIS], @a[sensor.Y_AXIS], @a[sensor.Z_AXIS])
        show_data(@"Accel (g):  ", a[sensor.X_AXIS], a[sensor.Y_AXIS], a[sensor.Z_AXIS])

        if ( _intflag )                         ' interrupt triggered
            intsource := sensor.accel_int()
            if ( intsource & sensor.INT_TRANS ) ' transient acceleration event
                temp := sensor.trans_interrupt()' clear the trans. interrupt
            if ( intsource & sensor.INT_AUTOSLPWAKE )
                sysmod := sensor.sys_mode()
                if ( sysmod & sensor.SLEEP )    ' op. mode is sleep,
                    outa[LED] := 0              '   so turn LED off
                elseif (sysmod & sensor.ACTIVE) ' else active,
                    outa[LED] := 1              '   turn it on

        if ( ser.getchar_noblock() == "c" )     ' press the 'c' key in the demo
            cal_accel()                         ' to calibrate sensor offsets


PUB cal_accel()
' Calibrate the accelerometer
    ser.pos_xy(0, 3)
    ser.str(@"Calibrating accelerometer...")
    sensor.calibrate_accel()
    ser.pos_xy(0, 3)
    ser.clear_ln()


PUB show_data(p_str, x, y, z) | axis, tmp[3], sign

    longmove(@tmp, @x, 3)

    ser.str(p_str)
    repeat axis from 0 to 2
        ' The sign is normally taken from the whole part and just displayed.
        ' Because we're showing values divided by 1_000_000, it won't show negative until the value
        '   reaches -1_000_000 or less, so values like -0_800_000 will display without the '-',
        '   so process the sign display separately here
        if ( tmp[axis] < 0 )
            sign := "-"
        else
            sign := " "
        ser.printf(@"%c%d.%06.6d     ", sign, ...
                                        ||(tmp[axis] / 1_000_000), ...
                                        ||(tmp[axis] // 1_000_000) )
    ser.newline()


PRI cog_isr()
' Interrupt service routine
    dira[INT1] := 0                             ' INT1 as input
    repeat
        waitpne(|< INT1, |< INT1, 0)            ' wait for INT1 (active low)
        _intflag := 1                           '   set flag
        waitpeq(|< INT1, |< INT1, 0)            ' now wait for it to clear
        _intflag := 0                           '   clear flag


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( sensor.start() )
        ser.strln(@"FXOS8700 driver started (I2C)")
    else
        ser.strln(@"FXOS8700 driver failed to start - halting")
        repeat

    cognew(cog_isr(), @_isr_stack)              ' start ISR in another core


DAT
{
Copyright 2025 Jesse Burt

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

