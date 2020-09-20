{
    --------------------------------------------
    Filename:
    Author:
    Description:
    Copyright (c) 2020
    Started Month Day, Year
    Updated Month Day, Year
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    LED         = cfg#LED1
    SER_RX      = cfg#SER_RX_DEF
    SER_TX      = cfg#SER_TX_DEF
    SER_BAUD    = 115_200

    I2C_SCL     = cfg#SCL
    I2C_SDA     = cfg#SDA
    I2C_HZ      = 400_000
' --

VAR

    long _overruns
OBJ

    cfg     : "core.con.boardcfg.flip"                      ' Constants for clock setup, I/O pins, etc
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    io      : "io"
    imu     : "sensor.imu.6dof.fxos8700.i2c"
    int     : "string.integer"

PUB Main{} | dispmode

    setup{}
    imu.accelopmode(imu#STANDBY)
'    imu.acceladcres(12)                                     ' 8, 10, 12 (low-power, normal, high-res, resp.)
    imu.accelscale(2)                                       ' 2, 4, 8, 16 (g's)
    imu.acceldatarate(50)                                   ' 1, 6, 12, 50, 100, 200, 400, 800
'    imu.accelaxisenabled(%111)                              ' 0 or 1 for each bit (%xyz)
'    imu.fifomode(imu#BYPASS)                                ' imu#BYPASS, imu#FIFO, imu#STREAM, imu#TRIGGER
'    imu.intthresh(1_000000)                                 ' 0..16_000000 (micro-g's, i.e., 0..16g)
'    imu.intmask(%100000)                                    ' Bits 5..0: Zhigh event | Zlow event | Yh|Yl|Xh|Xl

'    imu.magscale(1_3)
'    imu.magdatarate(15)

    imu.accelopmode(imu#MEASURE)
    ser.hidecursor{}
    dispmode := 0

    displaysettings{}
    repeat
        case ser.rxcheck{}
            "q", "Q":                                       ' Quit the demo
                ser.position(0, 15)
                ser.str(string("Halting"))
                imu.stop{}
                time.msleep(5)
                ser.stop
                quit
            "c", "C":                                       ' Perform calibration
                calibrate{}
                displaysettings{}
            "r", "R":                                       ' Change display mode: raw/calculated
                ser.position(0, 15)
                repeat 2
                    ser.clearline{}
                    ser.newline{}
                dispmode ^= 1

        ser.position(0, 15)
        case dispmode
            0:
                accelraw{}
                magraw{}
            1:
                accelcalc{}
                magcalc{}
    ser.showcursor{}

PUB AccelCalc{} | ax, ay, az

    repeat until imu.acceldataready{}
    imu.accelg (@ax, @ay, @az)
    if imu.acceldataoverrun{}
        _overruns++
    ser.str(string("accel micro-g: "))
    ser.str(int.decpadded(ax, 10))
    ser.str(int.decpadded(ay, 10))
    ser.str(int.decpadded(az, 10))
    ser.str(string("  Overruns: "))
    ser.dec (_overruns)
    ser.newline{}

PUB AccelRaw{} | ax, ay, az

    repeat until imu.acceldataready{}
    imu.accelData (@ax, @ay, @az)
    if imu.acceldataoverrun{}
        _overruns++
    ser.str(string("Raw accel: "))

    ser.str(int.decpadded(ax, 7))
    ser.str(int.decpadded(ay, 7))
    ser.str(int.decpadded(az, 7))
    ser.str(string("  Overruns: "))
    ser.dec (_overruns)
    ser.newline{}

PUB MagCalc{} | mx, my, mz

'    repeat until imu.magdataready{}
    imu.maggauss (@mx, @my, @mz)
    ser.str(string("Mag Gauss:   "))
    ser.str(int.decpadded(mx, 10))
    ser.str(int.decpadded(my, 10))
    ser.str(int.decpadded(mz, 10))
    ser.clearline{}
    ser.newline{}

PUB MagRaw{} | mx, my, mz

'    repeat until imu.magdataready{}
    imu.magdata (@mx, @my, @mz)
    ser.str(string("Mag raw:  "))

    ser.str(int.decpadded(mx, 7))
    ser.str(int.decpadded(my, 7))
    ser.str(int.decpadded(mz, 7))
    ser.clearline{}
    ser.newline{}

PUB Calibrate{}

    ser.position(0, 12)
    ser.str(string("Calibrating..."))
    imu.calibrateaccel{}
    imu.calibratemag{}
    ser.position(0, 12)
    ser.str(string("              "))

PUB DisplaySettings{}

    ser.position(0, 3)                                      ' Read back the settings from above
    ser.str(string("AccelOpMode: "))
    ser.dec(imu.accelopmode(-2))
    ser.newline
    ser.str(string("AccelScale: "))
    ser.dec(imu.accelscale(-2))
    ser.newline{}
'    ser.str(string("AccelADCRes: "))
'    ser.dec(imu.acceladcres(-2))
'    ser.newline{}
    ser.str(string("AccelDataRate: "))
    ser.dec(imu.acceldatarate(-2))
    ser.newline{}
'    ser.str(string("FIFOMode: "))
'    ser.str(lookupz(imu.fifomode(-2): string("BYPASS"), string("FIFO"), string("STREAM"), string("STREAM2FIFO")))
'    ser.newline{}
'    ser.str(string("IntThresh: "))
'    ser.dec(imu.intthresh(-2))
'    ser.newline{}
'    ser.str(string("IntMask: "))
'    ser.bin(imu.intmask(-2), 6)
'    ser.newline{}
'    ser.str(string("MagScale: "))                         '
'    ser.dec(imu.magscale(-2))
'    ser.newline{}
'    ser.str(string("MagDataRate: "))
'    ser.dec(imu.magdatarate(-2))
'    ser.newline{}
'    ser.str(string("MagOpMode: "))
'    ser.dec(imu.magopmode(-2))
'    ser.newline{}

PUB Setup{}

    repeat until ser.startrxtx (SER_RX, SER_TX, 0, SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if imu.startx(I2C_SCL, I2C_SDA, I2C_HZ)
        ser.strln(string("FXOS8700 driver started"))
    else
        ser.strln(string("FXOS8700 driver failed to start - halting"))
        imu.stop{}
        time.msleep(50)
        ser.stop{}

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE Jesse BurtS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
