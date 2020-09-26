{
    --------------------------------------------
    Filename: FXOS8700-Demo.spin
    Author: Jesse Burt
    Description: Demo of the FXOS8700 driver
    Copyright (c) 2020
    Started Sep 19, 2020
    Updated Sep 26, 2020
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
    SL_ADDR_BITS= %11                               ' %00..11 ($1E, 1D, 1C, 1F)
' --

    DATA_X_COL  = 20
    DATA_Y_COL  = DATA_X_COL+12
    DATA_Z_COL  = DATA_Y_COL+12
    DATA_OVR_COL= DATA_Z_COL+12

' Temperature scales
    C           = 0
    F           = 1
    K           = 2

VAR

    long _accel_overruns, _mag_overruns

OBJ

    cfg     : "core.con.boardcfg.flip"                      ' Constants for clock setup, I/O pins, etc
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    io      : "io"
    imu     : "sensor.imu.6dof.fxos8700.i2c"
    int     : "string.integer"

PUB Main{} | dispmode

    setup{}
    imu.opmode(imu#BOTH)
    imu.tempscale(C)
    imu.accelopmode(imu#MEASURE)
    imu.accellowpassfilter(false)
    imu.accelscale(2)                                       ' 2, 4, 8 (g's)
    imu.acceldatarate(50)                                   ' 1, 6, 12, 50, 100, 200, 400, 800
    imu.accelbias(0, 0, 0, 1)                               ' x, y, z: -128..127, rw: 0 (R), 1 (W)

    imu.magbias(0, 0, 0, 1)                                 ' x, y, z: -16384..16383, rw: 0 (R), 1 (W)

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

        ser.position (DATA_X_COL, 15)
        ser.char("X")
        ser.position (DATA_Y_COL, 15)
        ser.char("Y")
        ser.position (DATA_Z_COL, 15)
        ser.char("Z")
        ser.position (DATA_OVR_COL, 15)
        ser.str(string("Overruns:"))
        ser.newline{}
        case dispmode
            0:
                accelraw{}
                magraw{}
                temperature{}
            1:
                accelcalc{}
                magcalc{}
                temperature{}
    ser.showcursor{}

PUB AccelCalc{} | ax, ay, az

    repeat until imu.acceldataready{}
    imu.accelg (@ax, @ay, @az)
    if imu.acceldataoverrun{}
        _accel_overruns++
    ser.str(string("accel g: "))

    ser.positionx(DATA_X_COL)
    decimaldot(ax, 1_000_000)

    ser.positionx(DATA_Y_COL)
    decimaldot(ay, 1_000_000)

    ser.positionx(DATA_Z_COL)
    decimaldot(az, 1_000_000)

    ser.positionx(DATA_OVR_COL)
    ser.dec (_accel_overruns)
    ser.newline{}

PUB AccelRaw{} | ax, ay, az

    repeat until imu.acceldataready{}
    imu.acceldata(@ax, @ay, @az)
    if imu.acceldataoverrun{}
        _accel_overruns++
    ser.str(string("accel:   "))

    ser.positionx(DATA_X_COL)
    ser.str(int.decpadded(ax, 9))

    ser.positionx(DATA_Y_COL)
    ser.str(int.decpadded(ay, 9))

    ser.positionx(DATA_Z_COL)
    ser.str(int.decpadded(az, 9))

    ser.positionx(DATA_OVR_COL)
    ser.dec (_accel_overruns)
    ser.newline{}

PUB MagCalc{} | mx, my, mz

    repeat until imu.magdataready{}
    imu.maggauss(@mx, @my, @mz)
    if imu.magdataoverrun{}
        _mag_overruns++
    ser.str(string("mag Gs: "))

    ser.positionx(DATA_X_COL)
    decimaldot(mx, 1_000_000)

    ser.positionx(DATA_Y_COL)
    decimaldot(my, 1_000_000)

    ser.positionx(DATA_Z_COL)
    decimaldot(mz, 1_000_000)

    ser.positionx(DATA_OVR_COL)
    ser.dec (_mag_overruns)
    ser.newline{}

PUB MagRaw{} | mx, my, mz

    repeat until imu.magdataready{}
    imu.magdata(@mx, @my, @mz)
    if imu.magdataoverrun{}
        _mag_overruns++
    ser.str(string("mag:   "))

    ser.positionx(DATA_X_COL)
    ser.str(int.decpadded(mx, 9))

    ser.positionx(DATA_Y_COL)
    ser.str(int.decpadded(my, 9))

    ser.positionx(DATA_Z_COL)
    ser.str(int.decpadded(mz, 9))

    ser.positionx(DATA_OVR_COL)
    ser.dec (_mag_overruns)
    ser.newline{}

PUB Temperature{}

    ser.str(string("temp:"))

    ser.positionx(DATA_X_COL)
    decimaldot(imu.temperature{}, 100)
    ser.char(lookupz(imu.tempscale(-2): "C", "F", "K"))
    ser.newline{}

PUB Calibrate{}

    ser.position(0, 12)
    ser.str(string("Calibrating..."))
    imu.calibrateaccel{}
    imu.calibratemag{}
    ser.position(0, 12)
    ser.str(string("              "))

PUB DisplaySettings{} | axo, ayo, azo, mxo, myo, mzo

    ser.position(0, 3)                                      ' Read back the settings from above
    ser.str(string("AccelOpMode: "))
    ser.dec(imu.accelopmode(-2))
    ser.newline
    ser.str(string("AccelScale: "))
    ser.dec(imu.accelscale(-2))
    ser.newline{}
    imu.accelbias(@axo, @ayo, @azo, 0)
    ser.str(string("AccelBias: "))
    ser.dec(axo)
    ser.str(string("(x), "))
    ser.dec(ayo)
    ser.str(string("(y), "))
    ser.dec(azo)
    ser.str(string("(z)"))
    ser.newline{}
    ser.str(string("AccelDataRate: "))
    ser.dec(imu.acceldatarate(-2))
    ser.newline{}
'    ser.str(string("MagScale: "))                         '
'    ser.dec(imu.magscale(-2))
'    ser.newline{}
'    ser.str(string("MagDataRate: "))
'    ser.dec(imu.magdatarate(-2))
'    ser.newline{}
'    ser.str(string("MagOpMode: "))
'    ser.dec(imu.magopmode(-2))
'    ser.newline{}
    imu.magbias(@mxo, @myo, @mzo, 0)
    ser.str(string("MagBias: "))
    ser.dec(mxo)
    ser.str(string("(x), "))
    ser.dec(myo)
    ser.str(string("(y), "))
    ser.dec(mzo)
    ser.str(string("(z)"))
    ser.newline{}

PUB DecimalDot(scaled, divisor) | whole[4], part[4], places, tmp, sign
' Display a scaled up number in its natural form - scale it back down by divisor
    whole := scaled / divisor
    tmp := divisor
    places := 0
    part := 0
    sign := 0
    if scaled < 0
        sign := "-"
    else
        sign := " "

    repeat
        tmp /= 10
        places++
    until tmp == 1
    scaled //= divisor
    part := int.DecZeroed(||scaled, places)

    ser.char(sign)
    ser.Dec(||whole)
    ser.Char (".")
    ser.Str (part)

PUB Setup{}

    repeat until ser.startrxtx (SER_RX, SER_TX, 0, SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if imu.startx(I2C_SCL, I2C_SDA, I2C_HZ, SL_ADDR_BITS)
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
