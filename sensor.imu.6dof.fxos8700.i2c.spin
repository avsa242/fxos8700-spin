{
    --------------------------------------------
    Filename: sensor.imu.6dof.fxos8700.i2c.spin
    Author: Jesse Burt
    Description: Driver for the FXOS8700 6DoF IMU
    Copyright (c) 2020
    Started Sep 19, 2020
    Updated Sep 19, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR                = core#SLAVE_ADDR
    SLAVE_RD                = core#SLAVE_ADDR|1

    DEF_SCL                 = 28
    DEF_SDA                 = 29
    DEF_HZ                  = 100_000
    I2C_MAX_FREQ            = core#I2C_MAX_FREQ

' Indicate to user apps how many Degrees of Freedom each sub-sensor has
'   (also imply whether or not it has a particular sensor)
    ACCEL_DOF               = 3
    GYRO_DOF                = 0
    MAG_DOF                 = 3
    BARO_DOF                = 0
    DOF                     = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

' Bias adjustment (AccelBias(), GyroBias(), MagBias()) read or write
    R                       = 0
    W                       = 1

' Axis-specific constants
    X_AXIS                  = 0
    Y_AXIS                  = 1
    Z_AXIS                  = 2
    ALL_AXIS                = 3

' Temperature scale constants
    CELSIUS                 = 0
    FAHRENHEIT              = 1
    KELVIN                  = 2

' Endian constants
    LITTLE                  = 0
    BIG                     = 1

' FIFO modes
    BYPASS                  = 0
    FIFO                    = 1

' Operating modes
    STANDBY                 = 0
    MEASURE                 = 1

OBJ

    i2c     : "com.i2c"
    core    : "core.con.fxos8700.spin"
    time    : "time"

VAR

    long _ares, _abiasraw[3]
    long _mres, _mbiasraw[3]

PUB Null
'This is not a top-level object  

PUB Start{}
' Start using default I2C pins @ 100kHz
    startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, SCL_HZ): okay | tmp

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        okay := i2c.setupx(SCL_PIN, SDA_PIN, SCL_HZ)
        time.usleep (core#TPOR)
        if deviceid{} == core#DEVID_RESP
            defaults{}
            return okay
    stop{}
    return FALSE

PUB Stop{}

    i2c.terminate{}

PUB Defaults{}

PUB AccelADCRes(bits): curr_res

PUB AccelAxisEnabled(xyz_mask): curr_mask
' Enable data output for Accelerometer - per axis
'   Valid values: FALSE (0) or TRUE (1 or -1), for each axis
'   Any other value polls the chip and returns the current setting
    curr_mask := $00

PUB AccelBias(axbias, aybias, azbias, rw)
' Read or write/manually set accelerometer calibration offset values
'   Valid values:
'       rw:
'           R (0), W (1)
'       axbias, aybias, azbias:
'           -32768..32767
'   NOTE: When rw is set to READ, axbias, aybias and azbias must be addresses of respective variables to hold the returned
'       calibration offset values.
    case rw
        R:
            long[axbias] := _abiasraw[X_AXIS]
            long[aybias] := _abiasraw[Y_AXIS]
            long[azbias] := _abiasraw[Z_AXIS]

        W:
            case axbias
                -32768..32767:
                    _abiasraw[X_AXIS] := axbias
                OTHER:

            case aybias
                -32768..32767:
                    _abiasraw[Y_AXIS] := aybias
                OTHER:

            case azbias
                -32768..32767:
                    _abiasraw[Z_AXIS] := azbias
                OTHER:

PUB AccelClearInt{} | tmp
' Clears out any interrupts set up on the Accelerometer
'   and resets all Accelerometer interrupt registers to their default values.
    tmp := $00

PUB AccelData(ax, ay, az) | tmp[2]
' Reads the Accelerometer output registers
    readreg(core#OUT_X_MSB, 6, @tmp)
    long[ax] := ~~tmp.word[2]
    long[ay] := ~~tmp.word[1]
    long[az] := ~~tmp.word[0]

PUB AccelDataOverrun{}: flag
' Indicates previously acquired data has been overwritten
    flag := $00

PUB AccelDataRate(Hz): curr_hz
' Set accelerometer output data rate, in Hz
'   Valid values: 
'   Any other value polls the chip and returns the current setting
    curr_hz := $00

PUB AccelDataReady{}: flag
' Accelerometer sensor new data available
'   Returns TRUE or FALSE
    flag := $00

PUB AccelG(ax, ay, az) | tmpx, tmpy, tmpz
' Reads the Accelerometer output registers and scales the outputs to micro-g's (1_000_000 = 1.000000 g = 9.8 m/s/s)
    acceldata(@tmpx, @tmpy, @tmpz)
    long[ax] := tmpx * _ares
    long[ay] := tmpy * _ares
    long[az] := tmpz * _ares

PUB AccelInt{}: flag
' Flag indicating accelerometer interrupt asserted
'   Returns TRUE if interrupt asserted, FALSE if not
    flag := $00

PUB AccelOpMode(mode): curr_mode
' Set accelerometer operating mode
'   Valid values:
'       STANDBY (0): Standby
'       MEASURE (1): Measurement mode
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#CTRL_REG1, 1, @curr_mode)
    case mode
        STANDBY, MEASURE:
        other:
            return (curr_mode & 1)

    mode := ((curr_mode & core#ACTIVE_MASK) | mode) & core#CTRL_REG1_MASK
    writereg(core#CTRL_REG1, 1, @mode)

PUB AccelScale(g): curr_scale
' Sets the full-scale range of the Accelerometer, in g's
'   Valid values:
'   Any other value polls the chip and returns the current setting
    curr_scale := $00

PUB CalibrateAccel{} | tmpx, tmpy, tmpz, tmpbiasraw[3], axis, samples
' Calibrate the accelerometer
'   NOTE: The accelerometer must be oriented with the package top facing up for this method to be successful
    tmpx := tmpy := tmpz := axis := samples := 0
    longfill(@tmpbiasraw, 0, 3)
    accelbias(0, 0, 0, W)

    acceladcres(0)
    accelscale(0)       ' Set according to datasheet/AN recommendations
    acceldatarate(0)

    fifoenabled(TRUE)   ' Use the FIFO, if it exists
    fifomode(FIFO)
    fifothreshold (0)  ' Set according to datasheet/AN recommendations
    samples := fifothreshold(-2)
    repeat until fifofull{}

    repeat samples
' Read the accel data stored in the FIFO
        acceldata(@tmpx, @tmpy, @tmpz)
        tmpbiasraw[X_AXIS] += tmpx
        tmpbiasraw[Y_AXIS] += tmpy
        tmpbiasraw[Z_AXIS] += tmpz - (1_000_000 / _ares) ' Assumes sensor facing up!

    accelbias(tmpbiasraw[X_AXIS]/samples, tmpbiasraw[Y_AXIS]/samples, tmpbiasraw[Z_AXIS]/samples, W)

    fifoenabled(FALSE)
    fifomode(BYPASS)

PUB CalibrateMag{} | magmin[3], magmax[3], magtmp[3], axis, mx, my, mz, msb, lsb, samples
' Calibrates the Magnetometer on the FXOS8700 IMU module
    magtmp[0] := magtmp[1] := magtmp[2] := 0    'Initialize all variables to 0
    magmin[0] := magmin[1] := magmin[2] := 0
    magmax[0] := magmax[1] := magmax[2] := 0
    axis := mx := my := mz := msb := lsb := 0
    magbias(0, 0, 0, W)

    repeat samples
        repeat until magdataready
        magdata(@mx, @my, @mz)
        magtmp[X_AXIS] := mx
        magtmp[Y_AXIS] := my
        magtmp[Z_AXIS] := mz
        repeat axis from X_AXIS to Z_AXIS
            if (magtmp[axis] > magmax[axis])
                magmax[axis] := magtmp[axis]
            if (magtmp[axis] < magmin[axis])
                magmin[axis] := magtmp[axis]
    repeat axis from X_AXIS to Z_AXIS
        _mbiasraw[axis] := (magmax[axis] + magmin[axis]) / 2
        msb := (_mbiasraw[axis] & $FF00) >> 8
        lsb := _mbiasraw[axis] & $00FF

PUB DeviceID{}: id
' Read device identification
'   Returns: 
    readreg(core#WHO_AM_I, 1, @id)

PUB FIFOEnabled(enabled): curr_setting
' Enable FIFO memory
'   Valid values: FALSE (0), TRUE(1 or -1)
'   Any other value polls the chip and returns the current setting
    curr_setting := $00

PUB FIFOFull: flag
' FIFO Threshold status
'   Returns: FALSE (0): lower than threshold level, TRUE(-1): at or higher than threshold level
    flag := $00

PUB FIFOMode(mode): curr_mode
' Set FIFO behavior
'   Valid values:
'   Any other value polls the chip and returns the current setting
    curr_mode := $00

PUB FIFOThreshold(level): curr_lvl
' Set FIFO threshold level
'   Valid values:
'   Any other value polls the chip and returns the current setting
    curr_lvl := $00

PUB FIFOUnreadSamples: nr_samples
' Number of unread samples stored in FIFO
'   Returns:
    nr_samples := $00

PUB GyroAxisEnabled(xyz_mask): curr_mask
' Enable data output for Gyroscope - per axis
'   Valid values: FALSE (0) or TRUE (1 or -1), for each axis
'   Any other value polls the chip and returns the current setting
    curr_mask := $00
    case xyz_mask
        %000..%111:
        OTHER:
            return

PUB Interrupt{}: flag
' Flag indicating one or more interrupts asserted
'   Returns TRUE if one or more interrupts asserted, FALSE if not
    flag := $00

PUB IntMask(mask): curr_mask

PUB IntThresh(thresh): curr_thr

PUB MagBias(mxbias, mybias, mzbias, rw)
' Read or write/manually set Magnetometer calibration offset values
'   Valid values:
'       rw:
'           R (0), W (1)
'       mxbias, mybias, mzbias:
'           -32768..32767
'   NOTE: When rw is set to READ, mxbias, mybias and mzbias must be addresses of respective variables to hold the returned
'       calibration offset values.

    case rw
        R:
            long[mxbias] := _mbiasraw[X_AXIS]
            long[mybias] := _mbiasraw[Y_AXIS]
            long[mzbias] := _mbiasraw[Z_AXIS]

        W:
            case mxbias
                -32768..32767:
                    _mbiasraw[X_AXIS] := mxbias
                OTHER:

            case mybias
                -32768..32767:
                    _mbiasraw[Y_AXIS] := mybias
                OTHER:

            case mzbias
                -32768..32767:
                    _mbiasraw[Z_AXIS] := mzbias
                OTHER:
        OTHER:
            return

PUB MagClearInt{} | tmp
' Clear out any interrupts set up on the Magnetometer and
'   resets all Magnetometer interrupt registers to their default values
    tmp := $00

PUB MagData(mx, my, mz) | tmp[2]
' Read the Magnetometer output registers
    long[mx] := ~~tmp.word[0]
    long[my] := ~~tmp.word[1]
    long[mz] := ~~tmp.word[2]
    tmp := $00

PUB MagDataOverrun{}: flag
' Flag indicating magnetometer data has overrun
'   Returns:
'   NOTE: Overrun status indicates new data for axis has overwritten the previous data.
    flag := $00

PUB MagDataRate(Hz): curr_rate
' Set Magnetometer Output Data Rate, in Hz
'   Valid values:
'   Any other value polls the chip and returns the current setting
    curr_rate := $00

PUB MagDataReady{}: flag
' Flag indicating new magnetometer data is available.
'   Returns TRUE (-1) if data available, FALSE if not
    flag := $00

PUB MagGauss(mx, my, mz) | tmp[3]
' Read the Magnetometer output registers and scale the outputs to micro-Gauss (1_000_000 = 1.000000 Gs)
    magdata(@tmp[X_AXIS], @tmp[Y_AXIS], @tmp[Z_AXIS])
    long[mx] := tmp[X_AXIS] * _mres
    long[my] := tmp[Y_AXIS] * _mres
    long[mz] := tmp[Z_AXIS] * _mres

PUB MagInt{}: intsrc
' Magnetometer interrupt source(s)
'   Returns: Interrupts that are currently asserted, as a bitmask
    intsrc := $00

PUB MagIntsEnabled(enable_mask): curr_mask
' Enable magnetometer interrupts, as a bitmask
'   Valid values:
'
'   Any other value polls the chip and returns the current setting
    curr_mask := $00

PUB MagIntThresh(level): curr_thr
' Set magnetometer interrupt threshold
'   Valid values:
'   Any other value polls the chip and returns the current setting
    curr_thr := $00

PUB MagOpMode(mode): curr_mode
' Set magnetometer operating mode
'   Valid values:
'   Any other value polls the chip and returns the current setting
    curr_mode := $00

PUB MagScale(scale): curr_scl
' Set full scale of Magnetometer, in Gauss
'   Valid values:
'   Any other value polls the chip and returns the current setting
    curr_scl := $00

PUB OpMode(mode): curr_mode

PUB Temperature{}: temp
' Get temperature from chip
'   Returns: Temperature in hundredths of a degree Celsius (1000 = 10.00 deg C)
    temp := $00

PUB TempDataReady{}: flag
' Flag indicating new temperature sensor data available
'   Returns TRUE or FALSE
    flag := $00

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, tmp
' Read nr_bytes from device into ptr_buff
    case reg_nr                                     ' Validate regs
        $01, $03, $05, $33, $35, $37, $39, $3b, $3d:' Prioritize data output
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}                             ' S
            i2c.wr_block(@cmd_pkt, 2)               ' SL|W, reg_nr
            i2c.start{}                             ' Sr
            i2c.write(SLAVE_RD)                     ' SL|R
            i2c.rd_block(ptr_buff, nr_bytes, true)  ' R 0..nr_bytes-1
            i2c.stop{}                              ' P
        $00, $02, $04, $06, $09..$18, $1d..$32, $34, $36, $38, $3a, $3e..$78:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}                             ' S
            i2c.wr_block(@cmd_pkt, 2)               ' SL|W, reg_nr
            i2c.start{}                             ' Sr
            i2c.write(SLAVE_RD)                     ' SL|R
            i2c.rd_block(ptr_buff, nr_bytes, true)  ' R 0..nr_bytes-1
            i2c.stop{}                              ' P
        OTHER:
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, tmp
' Write nr_bytes to reg_nr
    case reg_nr
        $09, $0a, $0e, $0f, $11..$15, $17..$1d, $1f..$21, $23..$31, $3f..$44,{
        } $52, $54..$5d, $5f..$78:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}                             ' S
            i2c.wr_block(@cmd_pkt, 2)               ' SL|W, reg_nr
            i2c.wr_block(ptr_buff, nr_bytes)        ' W ptr_buff[0..nr_bytes-1]
            i2c.stop{}                              ' P

        OTHER:
            return
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
