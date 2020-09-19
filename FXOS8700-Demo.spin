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

OBJ

    cfg     : "core.con.boardcfg.flip"                      ' Constants for clock setup, I/O pins, etc
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    io      : "io"
    imu     : "sensor.imu.6dof.fxos8700.i2c"

PUB Main{}

    setup{}
    repeat

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
