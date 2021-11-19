{
    --------------------------------------------
    Filename: sensor.imu.6dof.fxos8700.i2c.spin
    Author: Jesse Burt
    Description: Driver for the FXOS8700 6DoF IMU
    Copyright (c) 2021
    Started Sep 19, 2020
    Updated Nov 18, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    I2C_MAX_FREQ    = core#I2C_MAX_FREQ

' Indicate to user apps how many Degrees of Freedom each sub-sensor has
'   (also imply whether or not it has a particular sensor)
    ACCEL_DOF       = 3
    GYRO_DOF        = 0
    MAG_DOF         = 3
    BARO_DOF        = 0
    DOF             = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

' Magnetometer scaling
    MRES_GAUSS      = 1000
    MRES_MICROTESLA = 100000

' Bias adjustment (AccelBias(), GyroBias(), MagBias()) read or write
    R               = 0
    W               = 1

' Axis-specific constants
    X_AXIS          = 0
    Y_AXIS          = 1
    Z_AXIS          = 2
    ALL_AXIS        = 3

' Temperature scale constants
    C               = 0
    F               = 1
    K               = 2

' Endian constants
    LITTLE          = 0
    BIG             = 1

' FIFO modes
    BYPASS          = 0
    STREAM          = 1
    FIFO            = 2
    TRIGGER         = 3

' Accel Operating modes
    STDBY           = 0
    ACTIVE          = 1

' Operating modes
    ACCEL           = 0
    MAG             = 1
    BOTH            = 3

' Interrupt sources
    INT_AUTOSLPWAKE = 1 << 7
    INT_TRANS       = 1 << 5
    INT_ORIENT      = 1 << 4
    INT_PULSE       = 1 << 3
    INT_FFALL       = 1 << 2
    INT_DRDY        = 1

OBJ

    i2c     : "com.i2c"                         ' PASM I2C engine
    core    : "core.con.fxos8700"               ' HW-specific constants
    time    : "time"                            ' timekeeping methods

VAR

    long _ares, _abiasraw[3]
    long _mres, _mbiasraw[3]
    byte _slave_addr, _temp_scale
    byte _opmode_orig
    byte _RES

PUB Null{}
' This is not a top-level object

PUB Start{}
' Start using "standard" Propeller I2C pins and 100kHz, default slave address
'   NOTE: Starts with no reset pin defined
    startx(DEF_SCL, DEF_SDA, DEF_HZ, %00, -1)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS, RES_PIN): status
' Start using custom pins, I2C bus freq, slave address bits
'   NOTE: RES_PIN is optional; specify -1, if unused
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            _RES := RES_PIN
            time.usleep(core#TPOR)
            ' Unfortunately, the chip's mapping of SAx bits to the slave address isn't
            '   logical, so to work around it, determine it conditionally:
            case ADDR_BITS
                %00: _slave_addr := core#SLAVE_ADDR_1E
                %01: _slave_addr := core#SLAVE_ADDR_1D
                %10: _slave_addr := core#SLAVE_ADDR_1C
                %11: _slave_addr := core#SLAVE_ADDR_1F
                other: _slave_addr := core#SLAVE_ADDR_1E

            if deviceid{} == core#DEVID_RESP
                defaults{}
                return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB Stop{}

    i2c.deinit{}

PUB Defaults{}
' Factory default settings
    accelopmode(STDBY)
    opmode(ACCEL)

    acceldatarate(800)
    accellowpassfilter(false)
    accelscale(2)
    fifoenabled(FALSE)
    fifothreshold(0)
    intmask(%00000000)
    magdataoversampling(2)
    'magdatarate(800)                           ' already set by acceldatarate
    magintsenabled(FALSE)
    magintthreshx(0)
    magintthreshy(0)
    magintthreshz(0)
    magintpersistence(0)
    magthreshintmask(%000)
    magthreshintsenabled(FALSE)
    tempscale(C)

PUB Preset_Active{}
' Like factory defaults, but with the following changes:
'   Accelerometer + Magnetometer enabled
'   Active/measurement mode
    defaults{}
    accelopmode(ACTIVE)
    opmode(BOTH)

PUB Preset_ClickDet{}
' Preset settings for click detection
    reset{}
    acceldatarate(400)
    accelscale(2)
    clickaxisenabled(%111111)                   ' enable X, Y, Z single tap det
    clickthreshx(1_575000)                      ' X: 1.575g thresh
    clickthreshy(1_575000)                      ' Y: 1.575g
    clickthreshz(2_650000)                      ' Z: 2.650g
    clicktime(50_000)
    clicklatency(300_000)
    doubleclickwindow(300_000)
    intmask(INT_PULSE)                          ' enable click/pulse interrupts
    introuting(INT_PULSE)                       ' route click ints to INT1 pin
    accelopmode(ACTIVE)

PUB AccelADCRes(bits): curr_res
' dummy method

PUB AccelAxisEnabled(xyz_mask): curr_mask
' dummy method
    return %111

PUB AccelBias(bias_x, bias_y, bias_z, rw) | tmp
' Read or write/manually set accelerometer calibration offset values
'   Valid values:
'       When rw == W (1, write)
'           bias_x, bias_y, bias_z: -128..127
'       When rw == R (0, read)
'           bias_x, bias_y, bias_z:
'               Pointers to variables to hold current settings for respective
'               axes
'   NOTE: When writing new offsets, any values outside of the range -128..127
'       will be clamped (e.g., calling with 131 will actually set 127)
    case rw
        R:
            readreg(core#OFF_X, 3, @tmp)
            long[bias_x] := ~tmp.byte[2]        ' signed 8-bit
            long[bias_y] := ~tmp.byte[1]
            long[bias_z] := ~tmp.byte[0]
        W:
            tmp.byte[2] := bias_x := -128 #> bias_x <# 127
            tmp.byte[1] := bias_y := -128 #> bias_y <# 127
            tmp.byte[0] := bias_z := -128 #> bias_z <# 127
            cacheopmode{}                       ' switch to stdby to mod regs
            writereg(core#OFF_X, 3, @tmp)
            restoreopmode{}                     ' restore original opmode

PUB AccelClearInt{} | tmp   ' TODO
' Clears out any interrupts set up on the Accelerometer
'   and resets all Accelerometer interrupt registers to their default values.
    tmp := 0

PUB AccelData(ptr_x, ptr_y, ptr_z) | tmp[2]
' Reads the Accelerometer output registers
    readreg(core#OUT_X_MSB, 6, @tmp)
    long[ptr_x] := ~~tmp.word[2]                ' signed 16-bit
    long[ptr_y] := ~~tmp.word[1]
    long[ptr_z] := ~~tmp.word[0]

PUB AccelDataOverrun{}: flag
' Indicates previously acquired data has been overwritten
'   Returns:
'       TRUE (-1): data overrun
'       FALSE (0): no data overrun
    flag := 0
    readreg(core#STATUS, 1, @flag)
    return ((flag >> 6) & core#ZYXOW_BITS) == %111

PUB AccelDataRate(rate): curr_rate
' Set accelerometer output data rate, in Hz
'   Valid values: 1(.5625), 6(.25), 12(.5), 50, 100, 200, 400, *800
'   Any other value polls the chip and returns the current setting
'   NOTE: If OpMode() is BOTH (3), the set data rate will be halved
'       (chip limitation)
    curr_rate := 0
    readreg(core#CTRL_REG1, 1, @curr_rate)
    case rate
        1, 6, 12, 50, 100, 200, 400, 800:
            rate := lookdownz(rate: 800, 400, 200, 100, 50, 12, 6, 1) << core#DR
        other:
            curr_rate := (curr_rate >> core#DR) & core#DR_BITS
            return lookupz(curr_rate: 800, 400, 200, 100, 50, 12, 6, 1)

    rate := ((curr_rate & core#DR_MASK) | rate) & core#CTRL_REG1_MASK
    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#CTRL_REG1, 1, @rate)
    restoreopmode{}                             ' restore original opmode

PUB AccelDataReady{}: flag
' Flag indicating new accelerometer data available
'   Returns TRUE (-1) if data ready, FALSE otherwise
    flag := 0
    readreg(core#STATUS, 1, @flag)
    return (flag & core#ZYXDR_BITS) == %111

PUB AccelG(ptr_x, ptr_y, ptr_z) | tmpx, tmpy, tmpz
' Reads the Accelerometer output registers and scales the outputs to micro-g's (1_000_000 = 1.000000 g = 9.8 m/s/s)
    acceldata(@tmpx, @tmpy, @tmpz)
    long[ptr_x] := tmpx * _ares
    long[ptr_y] := tmpy * _ares
    long[ptr_z] := tmpz * _ares

PUB AccelInt{}: flag 'TODO
' Flag indicating accelerometer interrupt asserted
'   Returns TRUE if interrupt asserted, FALSE if not
    flag := 0

PUB AccelLowPassFilter(state): curr_state
' Enable accelerometer data low-pass filter
'   Valid values: TRUE (-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This option simply enables a reduced noise mode - it doesn't
'       provide a LPF cutoff frequency setting, as in other IMUs
'   NOTE: This option cannot be used in 8g scale. If the accelerometer
'       scale is currently set to 8g, enabling this filter will be ignored
    curr_state := 0
    readreg(core#CTRL_REG1, 1, @curr_state)
    case ||(state)
        0:
            state := (curr_state & core#LNOISE_MASK)
        1:
            case accelscale(-2)
                2, 4:
                    state := (curr_state | (1 << core#LNOISE))
                8:
                    return FALSE
        other:
            return ((curr_state >> core#LNOISE) & 1) == 1

    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#CTRL_REG1, 1, @state)
    restoreopmode{}                             ' restore original opmode

PUB AccelOpMode(mode): curr_mode
' Set accelerometer operating mode
'   Valid values:
'      *STDBY (0): Standby
'       ACTIVE (1): Measurement mode
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#CTRL_REG1, 1, @curr_mode)
    case mode
        STDBY, ACTIVE:
        other:
            return (curr_mode & 1)

    mode := ((curr_mode & core#ACTIVE_MASK) | mode) & core#CTRL_REG1_MASK
    writereg(core#CTRL_REG1, 1, @mode)

PUB AccelScale(g): curr_scale
' Sets the full-scale range of the Accelerometer, in g's
'   Valid values: *2, 4, 8
'   Any other value polls the chip and returns the current setting
    curr_scale := 0
    readreg(core#XYZ_DATA_CFG, 1, @curr_scale)
    case g
        2, 4, 8:
            g := lookdownz(g: 2, 4, 8)
            _ares := lookupz(g: 61, 122, 244)
        other:
            curr_scale := (curr_scale & core#FS_BITS)
            return lookupz(curr_scale: 2, 4, 8)

    g := (curr_scale & core#FS_MASK) | g
    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#XYZ_DATA_CFG, 1, @g)
    restoreopmode{}                             ' restore original opmode

PUB CalibrateAccel{} | acceltmp[3], axis, ax, ay, az, samples, scale_orig, drate_orig, fifo_orig, scl
' Calibrate the accelerometer
'   NOTE: The accelerometer must be oriented with the package top facing up
'       for this method to be successful
    longfill(@acceltmp, 0, 12)
    accelbias(0, 0, 0, W)
    scale_orig := accelscale(-2)                ' Preserve user's original
    drate_orig := acceldatarate(-2)             '   settings
    fifo_orig := fifomode(-2)

    fifomode(BYPASS)                            ' Bypass FIFO, set accel
    accelscale(2)                               ' to most sensitive scale
    acceldatarate(100)                          ' and 100Hz data rate
    scl := _ares / 2                            ' Scale down to 2mg/LSB
    samples := 32
    repeat samples
        repeat until acceldataready{}
        acceldata(@ax, @ay, @az)
        acceltmp[X_AXIS] -= (ax / scl)          ' Accumulate samples
        acceltmp[Y_AXIS] -= (ay / scl)
        acceltmp[Z_AXIS] -= (az - (1_000_000 / _ares)) / scl

    repeat axis from X_AXIS to Z_AXIS           '   then average them
        acceltmp[axis] /= samples

    accelbias(acceltmp[X_AXIS], acceltmp[Y_AXIS], acceltmp[Z_AXIS], W)

    accelscale(scale_orig)
    acceldatarate(drate_orig)
    fifomode(fifo_orig)

PUB CalibrateMag{} | magtmp[3], axis, mx, my, mz, samples
' Calibrate the magnetometer
    longfill(@magtmp, 0, 8)                     ' Initialize vars to 0
    magbias(0, 0, 0, W)                         ' Clear out existing bias

    samples := 32
    repeat samples
        repeat until magdataready{}
        magdata(@mx, @my, @mz)
        magtmp[X_AXIS] += mx                    ' Accumulate samples
        magtmp[Y_AXIS] += my
        magtmp[Z_AXIS] += mz

    repeat axis from X_AXIS to Z_AXIS           '   then average them
        magtmp[axis] /= samples

    magbias(magtmp[X_AXIS], magtmp[Y_AXIS], magtmp[Z_AXIS], W)

PUB ClickAxisEnabled(mask): curr_mask
' Enable click detection per axis, and per click type
'   Valid values:
'       Bits: 5..0
'       [5..4]: Z-axis double-click..single-click
'       [3..2]: Y-axis double-click..single-click
'       [1..0]: X-axis double-click..single-click
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#PULSE_CFG, 1, @curr_mask)
    case mask
        %000000..%111111:
        other:
            return curr_mask & core#PEFE_BITS

    mask := ((curr_mask & core#PEFE_MASK) | mask)
    writereg(core#PULSE_CFG, 1, @mask)

pUB Clicked{}: flag
' Flag indicating the sensor was single or double-clicked
'   Returns: TRUE (-1) if sensor was single-clicked or double-clicked
'            FALSE (0) otherwise
    return (((clickedint{} >> core#EA) & 1) <> 0)

PUB ClickedInt{}: status
' Clicked interrupt status
'   Bits: 7..0
'       7: Interrupt active
'       6: Z-axis clicked
'       5: Y-axis clicked
'       4: X-axis clicked
'       3: Double-click on first event
'       2: Z-axis polarity (0: positive, 1: negative)
'       1: Y-axis polarity (0: positive, 1: negative)
'       0: X-axis polarity (0: positive, 1: negative)
    readreg(core#PULSE_SRC, 1, @status)

PUB ClickIntEnabled(state): curr_state
' Enable click interrupts on INT1
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    readreg(core#CTRL_REG4, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#INT_EN_PULSE
        other:
            return ((curr_state >> core#INT_EN_PULSE) == 1)

    state := ((curr_state & core#IE_PULSE_MASK) | state)
    writereg(core#CTRL_REG4, 1, @state)

PUB ClickLatency(ltime): curr_ltime | time_res, odr
'   Set minimum elapsed time from detection of first click to recognition of
'       any subsequent clicks (single or double), in microseconds. All clicks
'       *during* this time will be ignored.
'   Valid values:
'                                   Max time range
'                           ClickLPFEnabled()
'       AccelDataRate():    == 0        == 1
'       800                 318_000     638_000
'       400                 318_000     1_276_000
'       200                 638_000     2_560_000
'       100                 1_276_000   5_100_000
'       50                  2_560_000   10_200_000
'       12                  2_560_000   10_200_000
'       6                   2_560_000   10_200_000
'       1                   2_560_000   10_200_000
'   Any other value polls the chip and returns the current setting
    ' calc time resolution (in microseconds) based on AccelDataRate() (1/ODR),
    '   then limit to range spec'd in AN4072
    odr := acceldatarate(-2)
    if clicklpfenabled(-2)
        time_res := 2_500 #> ((1_000000/odr) * 2) <# 40_000
    else
        time_res := 1_250 #> ((1_000000/odr) / 2) <# 10_000

    ' check that the parameter is between 0 and the max time range for
    '   the current AccelDataRate() setting
    if (ltime => 0) and (ltime =< (time_res * 255))
        ltime /= time_res
        writereg(core#PULSE_LTCY, 1, @ltime)
    else
        readreg(core#PULSE_LTCY, 1, @curr_ltime)
        return (curr_ltime * time_res)

PUB ClickLPFEnabled(state): curr_state
' Enable click detection low-pass filter
'   Valid Values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#HP_FILT_CUTOFF, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#PLS_LPF_EN
        other:
            return (((curr_state >> core#PLS_LPF_EN) & 1) == 1)

    state := ((curr_state & core#PLS_LPF_EN_MASK) | state)
    writereg(core#HP_FILT_CUTOFF, 1, @state)

PUB ClickThresh(thresh): curr_thresh
' Set threshold for recognizing a click (all axes), in micro-g's
'   Valid values:
'       0..8_000000 (8g's)
'   NOTE: The allowed range is fixed at 8g's, regardless of the current
'       setting of AccelScale()
'   NOTE: If AccelLowNoiseMode() is set to LOWNOISE, the maximum threshold
'       recognized using this method will be 4_000000 (4g's)
    case thresh
        0..8_000000:
            clickthreshx(thresh)
            clickthreshy(thresh)
            clickthreshz(thresh)
        other:
            return

PUB ClickThreshX(thresh): curr_thresh
' Set threshold for recognizing a click (X-axis), in micro-g's
'   Valid values:
'       0..8_000000 (8g's)
'   Any other value polls the chip and returns the current setting
'   NOTE: The allowed range is fixed at 8g's, regardless of the current
'       setting of AccelScale()
'   NOTE: If AccelLowNoiseMode() is set to LOWNOISE, the maximum threshold
'       recognized using this method will be 4_000000 (4g's)
    case thresh
        0..8_000000:
            thresh /= 0_063000
            writereg(core#PULSE_THSX, 1, @thresh)
        other:
            readreg(core#PULSE_THSX, 1, @curr_thresh)
            return curr_thresh * 0_063000       ' scale to 1..8_000000 (8g's)

PUB ClickThreshY(thresh): curr_thresh
' Set threshold for recognizing a click (Y-axis), in micro-g's
'   Valid values:
'       0..8_000000 (8g's)
'   Any other value polls the chip and returns the current setting
'   NOTE: The allowed range is fixed at 8g's, regardless of the current
'       setting of AccelScale()
'   NOTE: If AccelLowNoiseMode() is set to LOWNOISE, the maximum threshold
'       recognized using this method will be 4_000000 (4g's)
    case thresh
        0..8_000000:
            thresh /= 0_063000
            writereg(core#PULSE_THSY, 1, @thresh)
        other:
            readreg(core#PULSE_THSY, 1, @curr_thresh)
            return curr_thresh * 0_063000       ' scale to 1..8_000000 (8g's)

PUB ClickThreshZ(thresh): curr_thresh
' Set threshold for recognizing a click (Z-axis), in micro-g's
'   Valid values:
'       0..8_000000 (8g's)
'   Any other value polls the chip and returns the current setting
'   NOTE: The allowed range is fixed at 8g's, regardless of the current
'       setting of AccelScale()
'   NOTE: If AccelLowNoiseMode() is set to LOWNOISE, the maximum threshold
'       recognized using this method will be 4_000000 (4g's)
    case thresh
        0..8_000000:
            thresh /= 0_063000
            writereg(core#PULSE_THSZ, 1, @thresh)
        other:
            readreg(core#PULSE_THSZ, 1, @curr_thresh)
            return curr_thresh * 0_063000       ' scale to 1..8_000000 (8g's)

PUB ClickTime(ctime): curr_ctime | time_res, odr
' Set maximum elapsed interval between start of click and end of click, in uSec
'   (i.e., time from set ClickThresh exceeded to falls back below threshold)
'   Valid values:
'                                   Max time range
'                           ClickLPFEnabled()
'       AccelDataRate():    == 0        == 1
'       800                 159_000     319_000
'       400                 159_000     638_000
'       200                 319_000     1_280_000
'       100                 638_000     2_550_000
'       50                  1_280_000   5_100_000
'       12                  1_280_000   5_100_000
'       6                   1_280_000   5_100_000
'       1                   1_280_000   5_100_000
'   Any other value polls the chip and returns the current setting
    ' calc time resolution (in microseconds) based on AccelDataRate() (1/ODR),
    '   then limit to range spec'd in AN4072
    odr := acceldatarate(-2)
    if clicklpfenabled(-2)
        time_res := 1_250 #> ((1_000000/odr)) <# 20_000
    else
        time_res := 0_625 #> ((1_000000/odr) / 4) <# 5_000

    ' check that the parameter is between 0 and the max time range for
    '   the current AccelDataRate() setting
    if (ctime => 0) and (ctime =< (time_res * 255))
        ctime /= time_res
        writereg(core#PULSE_TMLT, 1, @ctime)
    else
        readreg(core#PULSE_TMLT, 1, @curr_ctime)
        return (curr_ctime * time_res)

PUB DoubleClickWindow(dctime): curr_dctime | time_res, odr
' Set maximum elapsed interval between two consecutive clicks, in uSec
'   Valid values:
'                                   Max time range
'                           ClickLPFEnabled()
'       AccelDataRate():    == 0        == 1
'       800                 318_000     638_000
'       400                 318_000     1_276_000
'       200                 638_000     2_560_000
'       100                 1_276_000   5_100_000
'       50                  2_560_000   10_200_000
'       12                  2_560_000   10_200_000
'       6                   2_560_000   10_200_000
'       1                   2_560_000   10_200_000
'   Any other value polls the chip and returns the current setting
    ' calc time resolution (in microseconds) based on AccelDataRate() (1/ODR),
    '   then limit to range spec'd in AN4072
    odr := acceldatarate(-2)
    if clicklpfenabled(-2)
        time_res := 2_500 #> ((1_000000/odr) * 2) <# 40_000
    else
        time_res := 1_250 #> ((1_000000/odr) / 2) <# 10_000

    ' check that the parameter is between 0 and the max time range for
    '   the current AccelDataRate() setting
    if (dctime => 0) and (dctime =< (time_res * 255))
        dctime /= time_res
        writereg(core#PULSE_WIND, 1, @dctime)
    else
        readreg(core#PULSE_WIND, 1, @curr_dctime)
        return (curr_dctime * time_res)

PUB DeviceID{}: id
' Read device identification
'   Returns: $C7
    readreg(core#WHO_AM_I, 1, @id)

PUB FIFOEnabled(state): curr_state
' Enable FIFO memory
'   Valid values: *FALSE (0), TRUE(1 or -1)
'   Any other value polls the chip and returns the current setting
    case ||(state)
        0, 1:
            fifomode(||(state))
        other:
            curr_state := 0
            return fifomode(-2)

PUB FIFOFull{}: flag
' Flag indicating FIFO full/overflowed
'   Returns:
'       FALSE (0): FIFO not full
'       TRUE (-1): FIFO full/overflowed
    flag := 0
    readreg(core#F_STATUS, 1, @flag)
    return ((flag >> core#F_OVF) & 1) == 1

PUB FIFOMode(mode): curr_mode | fmode_bypass
' Set FIFO behavior
'   Valid values:
'      *BYPASS (0): FIFO bypassed/disabled
'       STREAM (1): FIFO enabled, circular buffer
'       FIFO (2): FIFO enabled, stop sampling when FIFO full
'       TRIGGER (3): FIFO enabled, circular buffer. Once triggered, FIFO will
'           continue to sample until full. The newest data will be discarded.
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#F_SETUP, 1, @curr_mode)
    case mode
        BYPASS, STREAM, FIFO, TRIGGER:
            mode := mode << core#F_MODE
        other:
            return ((curr_mode >> core#F_MODE) & core#F_MODE_BITS)

    fmode_bypass := (curr_mode & core#F_MODE_MASK)
    mode := (fmode_bypass | mode) & core#F_SETUP_MASK
' In order to switch between _active_ FIFO modes, it must first be disabled:
    if ((curr_mode >> core#F_MODE) & core#F_MODE_BITS) <> BYPASS
        writereg(core#F_SETUP, 1, @fmode_bypass)

    writereg(core#F_SETUP, 1, @mode)

PUB FIFOThreshold(level): curr_lvl
' Set FIFO watermark/threshold level
'   Valid values: 0..32 (default: 0)
'   Any other value polls the chip and returns the current setting
    curr_lvl := 0
    readreg(core#F_SETUP, 1, @curr_lvl)
    case level
        0..32:
        other:
            return (curr_lvl & core#F_WMRK_BITS)

    level := ((curr_lvl & core#F_WMRK_MASK) | level) & core#F_SETUP_MASK

    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#F_SETUP, 1, @level)
    restoreopmode{}                             ' restore original opmode

PUB FIFOUnreadSamples: nr_samples
' Number of unread samples stored in FIFO
'   Returns: 0..32
    nr_samples := 0
    readreg(core#F_STATUS, 1, @nr_samples)
    return (nr_samples & core#F_CNT_BITS)

PUB IntClear(clear_mask) | i, reg_nr, tmp
' Clear interrupts, per clear_mask
'   Valid values:
'       Bits: [5..0]: 1: clear interrupt, 0: don't clear interrupt
'           5: Auto-sleep/wake interrupt
'           4: FIFO interrupt
'           3: Transient interrupt
'           2: Orientation (portrait/landscape) interrupt
'           1: Pulse detection interrupt
'           0: Freefall/motion interrupt
'   NOTE: Acceleration vector-magnitude interrupt is cleared by
'       reading Interrupt()
'   NOTE: Data-ready interrupt is cleared by reading the acceleration data
'       and/or magnetometer data, as applicable
    case clear_mask
        0..%111111:
            repeat i from 5 to 0                    ' Each int is cleared by
                if clear_mask & (1 << (i+2))        ' reading a different reg
                    reg_nr := lookdownz(i: core#A_FFMT_SRC, core#PULSE_SRC, {
                    }core#PL_STATUS, core#TRANSIENT_SRC, core#F_STATUS, {
                    }core#SYSMOD)                   ' Sweep through all, and
                    readreg(reg_nr, 1, @tmp)        ' clear those with bits
                                                    ' marked '1'
        other:
            return

PUB Interrupt{}: int_src
' Indicate interrupt state
'   Returns:
'       Bits: [7..0]: 1: interrupt asserted, 0: interrupt inactive
'           7: Auto-sleep/wake interrupt
'           6: FIFO interrupt
'           5: Transient interrupt
'           4: Orientation (portrait/landscape) interrupt
'           3: Pulse detection interrupt
'           2: Freefall/motion interrupt
'           1: Acceleration vector-magnitude interrupt
'           0: Data-ready interrupt
'   NOTE: Bit 1/Acceleration vector-magnitude interrupt is cleared by
'       reading this flag
'   NOTE: Bit 0/Data-ready interrupt is cleared by reading the acceleration
'       data and/or magnetometer data, as applicable
    int_src := 0
    readreg(core#INT_SOURCE, 1, @int_src)

PUB IntMask(mask): curr_mask
' Set interrupt mask
'   Valid values:
'       Bits: [7..0]
'           7: Auto-sleep/wake interrupt
'           6: FIFO interrupt
'           5: Transient interrupt
'           4: Orientation (portrait/landscape) interrupt
'           3: Pulse detection interrupt
'           2: Freefall/motion interrupt
'           1: Acceleration vector-magnitude interrupt
'           0: Data-ready interrupt
'           (default: %00000000)
'   Any other value polls the chip and returns the current setting
    case mask
        0..%11111111:
            cacheopmode{}                       ' switch to stdby to mod regs
            writereg(core#CTRL_REG4, 1, @mask)
            restoreopmode{}                     ' restore original opmode
        other:
            curr_mask := 0
            readreg(core#CTRL_REG4, 1, @curr_mask)

PUB IntRouting(mask): curr_mask
' Set routing of interrupt sources to INT1 or INT2 pin
'   Valid values:
'       Setting a bit routes the interrupt to INT1
'       Clearing a bit routes the interrupt to INT2
'
'       Bits [7..0] (OR together symbols, as needed)
'       7: INT_AUTOSLPWAKE - Auto-sleep/wake
'       6: NOT FIFO - FIFO
'       5: INT_TRANS - Transient
'       4: INT_ORIENT - Orientation (landscape/portrait)
'       3: INT_PULSE - Pulse detection
'       2: INT_FFALL - Freefall/motion
'       1: INT_VECM - Accel. vector-magnitude
'       0: INT_DRDY - Data ready
'   Any other value polls the chip and returns the current setting
    case mask
        %00000000..%11111111:
            mask &= core#CTRL_REG5_MASK
            cacheopmode{}                       ' switch to stdby to mod regs
            writereg(core#CTRL_REG5, 1, @mask)
            restoreopmode{}                     ' restore original opmode
        other:
            readreg(core#CTRL_REG5, 1, @curr_mask)
            return

PUB IntThresh(thresh): curr_thr 'TODO

PUB MagBias(bias_x, bias_y, bias_z, rw) | tmp[2]
' Read or write/manually set magnetometer calibration offset values
'   Valid values:
'       When rw == W (1, write)
'           bias_x, bias_y, bias_z: -16384..16384
'       When rw == R (0, read)
'           bias_x, bias_y, bias_z:
'               Pointers to variables to hold current settings for respective
'               axes
'   NOTE: When writing new offsets, any values outside of the range
'       -16384..16383 will be clamped (e.g., calling with 16390 will actually
'       set 16383)
    case rw
        R:
            readreg(core#M_OFF_X_MSB, 6, @tmp)
            long[bias_x] := ~~tmp.word[2]
            long[bias_y] := ~~tmp.word[1]
            long[bias_z] := ~~tmp.word[0]
        W:
            tmp.word[2] := bias_x := (-16384 #> bias_x <# 16383) << 1
            tmp.word[1] := bias_y := (-16384 #> bias_y <# 16383) << 1
            tmp.word[0] := bias_z := (-16384 #> bias_z <# 16383) << 1
            writereg(core#M_OFF_X_MSB, 6, @tmp)

PUB MagClearInt{} | tmp 'TODO
' Clear out any interrupts set up on the Magnetometer and
'   resets all Magnetometer interrupt registers to their default values
    tmp := 0

PUB MagData(mx, my, mz) | tmp[2]
' Read the Magnetometer output registers
    tmp := 0
    readreg(core#M_OUT_X_MSB, 6, @tmp)
    long[mx] := ~~tmp.word[2]
    long[my] := ~~tmp.word[1]
    long[mz] := ~~tmp.word[0]

PUB MagDataOverrun{}: flag
' Flag indicating magnetometer data has overrun
'   Returns:
'       TRUE (-1): data overrun
'       FALSE (0): no data overrun
    flag := 0
    readreg(core#M_DR_STATUS, 1, @flag)
    return ((flag >> core#ZYXOW) & 1) == 1

PUB MagDataOverSampling(ratio): curr_ratio
' Set oversampling ratio for magnetometer output data
'   Valid values: (dependent upon current MagDataRate())
'       2, 4, 8, 16, 32, 64, 128, 256, 512, 1024
'       (default value for each data rate indicated in below tables)
'   Any other value polls the chip and returns the current setting
    curr_ratio := 0
    readreg(core#M_CTRL_REG1, 1, @curr_ratio)
    case magdatarate(-2)
        1:                                      ' OSR settings available for
            case ratio                          '   1Hz data rate:
                {*}16, 32, 64, 128, 256, 512, 1024:
                    ratio := lookdownz(ratio: 16, 16, 32, 64, 128, 256, 512, 1024)
                    ratio <<= core#M_OS
                other:
                    curr_ratio := (curr_ratio >> core#M_OS) & core#M_OS_BITS
                    return lookupz(curr_ratio: 16, 16, 32, 64, 128, 256, 512, 1024)
        6:
            case ratio
                {*}4, 8, 16, 32, 64, 128, 256:
                    ratio := lookdownz(ratio: 4, 4, 8, 16, 32, 64, 128, 256)
                    ratio <<= core#M_OS
                other:
                    curr_ratio := (curr_ratio >> core#M_OS) & core#M_OS_BITS
                    return lookupz(curr_ratio: 4, 4, 8, 16, 32, 64, 128, 256)
        12:
            case ratio
                {*}2, 4, 8, 16, 32, 64, 128:
                    ratio := lookdownz(ratio: 2, 2, 4, 8, 16, 32, 64, 128)
                    ratio <<= core#M_OS
                other:
                    curr_ratio := (curr_ratio >> core#M_OS) & core#M_OS_BITS
                    return lookupz(curr_ratio: 2, 2, 4, 8, 16, 32, 64, 128)
        50:
            case ratio
                {*}2, 4, 8, 16, 32:
                    ratio := lookdownz(ratio: 2, 2, 2, 2, 4, 8, 16, 32)
                    ratio <<= core#M_OS
                other:
                    curr_ratio := (curr_ratio >> core#M_OS) & core#M_OS_BITS
                    return lookupz(curr_ratio: 2, 2, 2, 2, 4, 8, 16, 32)
        100:
            case ratio
                {*}2, 4, 8, 16:
                    ratio := lookdownz(ratio: 2, 2, 2, 2, 2, 4, 8, 16)
                    ratio <<= core#M_OS
                other:
                    curr_ratio := (curr_ratio >> core#M_OS) & core#M_OS_BITS
                    return lookupz(curr_ratio: 2, 2, 2, 2, 2, 4, 8, 16)
        200:
            case ratio
                {*}2, 4, 8:
                    ratio := lookdownz(ratio: 2, 2, 2, 2, 2, 2, 4, 8)
                    ratio <<= core#M_OS
                other:
                    curr_ratio := (curr_ratio >> core#M_OS) & core#M_OS_BITS
                    return lookupz(curr_ratio: 2, 2, 2, 2, 2, 2, 4, 8)
        400:
            case ratio
                {*}2, 4:
                    ratio := lookdownz(ratio: 2, 2, 2, 2, 2, 2, 2, 4)
                    ratio <<= core#M_OS
                other:
                    curr_ratio := (curr_ratio >> core#M_OS) & core#M_OS_BITS
                    return lookupz(curr_ratio: 2, 2, 2, 2, 2, 2, 2, 4)
        800:
            case ratio
                {*}2:
                other:
                    return 2

    ratio := ((curr_ratio & core#M_OS_MASK) | ratio) & core#M_CTRL_REG1_MASK
    writereg(core#M_CTRL_REG1, 1, @ratio)

PUB MagDataRate(rate): curr_rate
' Set Magnetometer Output Data Rate, in Hz
'   Valid values: 1(.5625), 6(.25), 12(.5), 50, 100, 200, 400, *800
'   Any other value polls the chip and returns the current setting
'   NOTE: If OpMode() is BOTH (3), the set data rate will be halved
'       (chip limitation)
    curr_rate := acceldatarate(rate)

PUB MagDataReady{}: flag
' Flag indicating new magnetometer data available
'   Returns TRUE (-1) if data ready, FALSE otherwise
    flag := 0
    readreg(core#M_DR_STATUS, 1, @flag)
    return (flag & core#ZYXDR_BITS) == %111

PUB MagGauss(ptr_x, ptr_y, ptr_z) | tmp[3]
' Magnetometer data scaled to micro-Gauss (1_000_000 = 1.000000 Gs)
    magdata(@tmp[X_AXIS], @tmp[Y_AXIS], @tmp[Z_AXIS])
    long[ptr_x] := tmp[X_AXIS] * MRES_GAUSS
    long[ptr_y] := tmp[Y_AXIS] * MRES_GAUSS
    long[ptr_z] := tmp[Z_AXIS] * MRES_GAUSS

PUB MagInt{}: magintsrc
' Magnetometer interrupt source(s)
'   Returns: Interrupts that are currently asserted, as a bitmask
'       Bits: 210
'           2: Magnetic threshold interrupt
'           1: Magnetic vector-magnitude interrupt
'           0: Magnetic data-ready interrupt
    magintsrc := 0
    readreg(core#M_INT_SRC, 1, @magintsrc)

PUB MagIntPersistence(cycles): curr_cyc
' Set interrupt persistence, in cycles
'   Defines how many consecutive measurements must be outside the interrupt threshold
'   before an interrupt is actually triggered (e.g., to reduce false positives)
'   Valid values:
'       0..255
'   Any other value polls the device and returns the current setting
    case cycles
        0..255:
            writereg(core#M_THS_COUNT, 1, @cycles)
        other:
            curr_cyc := 0
            readreg(core#M_THS_COUNT, 1, @curr_cyc)
            return

PUB MagIntRouting(mask): curr_mask
' Set routing of interrupt sources to INT1 or INT2 pin
'   Valid values:
'       Setting a bit routes the interrupt to INT1
'       Clearing a bit routes the interrupt to INT2
'
'       Bits [0]
'       0: Magnetometer threshold interrupt
    curr_mask := 0
    readreg(core#M_THS_CFG, 1, @curr_mask)
    case mask
        0, 1:
        other:
            return (curr_mask & 1)

    mask := ((curr_mask & core#THS_INT_CFG_MASK) | mask)
    writereg(core#M_THS_CFG, 1, @mask)

PUB MagIntsEnabled(state): curr_state
' Enable magnetometer data threshold interrupt
'   Valid values: TRUE (-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#M_THS_CFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#THS_INT_EN
        other:
            return ((curr_state >> core#THS_INT_EN) & 1) == 1

    state := ((curr_state & core#THS_INT_EN_MASK) | state) & core#M_THS_CFG_MASK
    writereg(core#M_THS_CFG, 1, @state)

PUB MagIntThresh(level): curr_thr 'TODO
' Set magnetometer interrupt threshold
'   Valid values:
'   Any other value polls the chip and returns the current setting
    curr_thr := 0

PUB MagIntThreshX(thresh): curr_thr
' Set magnetometer interrupt X-axis threshold, in micro-Gauss
'   Valid values: 0..32_767000 (0..32.767Gs, default: 0)
'   Any other value polls the chip and returns the current setting
    case thresh
        0..32_767000:
            thresh /= 1000                      ' LSB = 0.1uT or 0.001Gs
            writereg(core#M_THS_X_MSB, 2, @thresh)
        other:
            curr_thr := 0
            readreg(core#M_THS_X_MSB, 2, @curr_thr)
            return curr_thr * 1000

PUB MagIntThreshY(thresh): curr_thr
' Set magnetometer interrupt Y-axis threshold, in micro-Gauss
'   Valid values: 0..32_767000 (0..32.767Gs, default: 0)
'   Any other value polls the chip and returns the current setting
    case thresh
        0..32_767000:
            thresh /= 1000                      ' LSB = 0.1uT or 0.001Gs
            writereg(core#M_THS_Y_MSB, 2, @thresh)
        other:
            curr_thr := 0
            readreg(core#M_THS_Y_MSB, 2, @curr_thr)
            return curr_thr * 1000

PUB MagIntThreshZ(thresh): curr_thr
' Set magnetometer interrupt Z-axis threshold, in micro-Gauss
'   Valid values: 0..32_767000 (0..32.767Gs, default: 0)
'   Any other value polls the chip and returns the current setting
    case thresh
        0..32_767000:
            thresh /= 1000                      ' LSB = 0.1uT or 0.001Gs
            writereg(core#M_THS_Z_MSB, 2, @thresh)
        other:
            curr_thr := 0
            readreg(core#M_THS_Z_MSB, 2, @curr_thr)
            return curr_thr * 1000

PUB MagOpMode(mode): curr_mode 'TODO
' Set magnetometer operating mode
'   Valid values:
'   Any other value polls the chip and returns the current setting
    curr_mode := 0

PUB MagScale(scale): curr_scl
' Set magnetometer full-scale range, in Gauss
'   Valid values: N/A (fixed at 12Gs, 1200uT)
'   Returns: 12
'   NOTE: For API-compatibility only
    return 12

PUB MagTesla(ptr_x, ptr_y, ptr_z) | tmp[3] 'XXX not overflow protected
' Magnetometer data scaled to micro-Teslas (1_000_000 = 1.000000 uT)
    magdata(@tmp[X_AXIS], @tmp[Y_AXIS], @tmp[Z_AXIS])
    long[ptr_x] := tmp[X_AXIS] * MRES_MICROTESLA
    long[ptr_y] := tmp[Y_AXIS] * MRES_MICROTESLA
    long[ptr_z] := tmp[Z_AXIS] * MRES_MICROTESLA

PUB MagThreshInt{}: int_src
' Magnetometer threshold-related interrupt source(s)
'   Returns: Interrupts that are currently asserted, as a bitmask
'       Bits: 76543210
'           State indicated when bit is set, unless otherwise noted:
'           7: One or more flags asserted
'           5: Z-axis high interrupt
'           4: Z-axis flag negative (1), or positive (0)
'           3: Y-axis high interrupt
'           2: Y-axis flag negative (1), or positive (0)
'           1: X-axis high interrupt
'           0: X-axis flag negative (1), or positive (0)
'   NOTE: Bits 5..0 will always indicate 0 if the respective thresholds
'       are set to 0
    readreg(core#M_THS_SRC, 1, @int_src)

PUB MagThreshIntMask(mask): curr_mask
' Set magnetometer threshold interrupt mask
'   Bits: [2..0]
'       2: Enable Z-axis threshold interrupt
'       1: Enable Y-axis threshold interrupt
'       0: Enable X-axis threshold interrupt
'       (default: %000)
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#M_THS_CFG, 1, @curr_mask)
    case mask
        0..%111:
            mask <<= core#THS_EFE
        other:
            return curr_mask >> core#THS_EFE

    mask := (curr_mask & core#THS_EFE_MASK) | mask
    writereg(core#M_THS_CFG, 1, @mask)

PUB MagThreshIntsEnabled(state): curr_state
' Enable magnetometer threshold interrupts
'   Valid values: TRUE (-1 or 1), *FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#M_THS_CFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#THS_INT_EN
        other:
            return ((curr_state >> core#THS_INT_EN) & 1) == 1

    state := ((curr_state & core#THS_INT_EN_MASK) | state) & core#M_THS_CFG_MASK
    writereg(core#M_THS_CFG, 1, @state)

PUB OpMode(mode): curr_mode
' Set operating mode
'   Valid values:
'      *ACCEL (0): Accelerometer only
'       MAG (1): Magnetometer only
'       BOTH (3): Both sensors active
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#M_CTRL_REG1, 1, @curr_mode)
    case mode
        ACCEL, MAG, BOTH:
        other:
            return (curr_mode & core#M_HMS_BITS)

    mode := ((curr_mode & core#M_HMS_MASK) | mode) & core#M_CTRL_REG1_MASK
    writereg(core#M_CTRL_REG1, 1, @mode)

PUB Reset{} | tmp
' Perform hard or soft-reset
    if lookdown(_RES: 0..31)
        outa[_RES] := 0
        dira[_RES] := 1
        outa[_RES] := 1
        time.usleep(core#TPOR)
        outa[_RES] := 0
    else
        tmp := core#SRESET
        writereg(core#CTRL_REG2, 1, @tmp)
        time.usleep(core#TPOR)

PUB Temperature{}: temp
' Read chip temperature
'   Returns: Temperature in hundredths of a degree Celsius (1000 = 10.00 deg C)
'   NOTE: OpMode() must be set to MAG (1) or BOTH (3) to read data from
'       the temperature sensor
'   NOTE: Output data rate is unaffected by AccelDataRate() or
'       MagDataRate() settings
    temp := 0
    readreg(core#TEMP, 1, @temp)
    temp *= 96                                  ' Res is 0.96C per LSB
    case _temp_scale
        C:
        F:
            temp := ((temp * 9_00) / 5_00) + 32_00
        K:
            temp += 273_15

PUB TempDataReady{}: flag
' Flag indicating new temperature sensor data available
'   Returns: TRUE (-1)
'   NOTE: For API compatibility only
    return TRUE

PUB TempScale(scale): curr_scale
' Set temperature scale used by Temperature method
'   Valid values:
'      *C (0): Celsius
'       F (1): Fahrenheit
'   Any other value returns the current setting
    case scale
        C, F, K:
            _temp_scale := scale
        other:
            return _temp_scale

PRI cacheOpMode{}
' Store the current operating mode, and switch to standby if different
'   (required for modifying some registers)
    _opmode_orig := accelopmode(-2)
    if _opmode_orig <> STDBY                    ' must be in standby to change
        accelopmode(STDBY)                      '   control regs

PRI restoreOpMode{}
' Restore original operating mode
    if _opmode_orig <> STDBY                    ' restore original opmode
        accelopmode(_opmode_orig)

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from device into ptr_buff
    case reg_nr                                 ' Validate regs
        $01, $03, $05, $33, $35, $37, $39, $3b, $3d:' Prioritize data output
            cmd_pkt.byte[0] := _slave_addr
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}                         ' S
            i2c.wrblock_lsbf(@cmd_pkt, 2)       ' SL|W, reg_nr
            i2c.start{}                         ' Sr
            i2c.write(_slave_addr | 1)          ' SL|R
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)' R sl -> ptr_buff
            i2c.stop{}                          ' P
        $00, $02, $04, $06, $09..$18, $1d..$32, $34, $36, $38, $3a, $3e..$78:
            cmd_pkt.byte[0] := _slave_addr
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}                         ' S
            i2c.wrblock_lsbf(@cmd_pkt, 2)       ' SL|W, reg_nr
            i2c.start{}                         ' Sr
            i2c.write(_slave_addr | 1)          ' SL|R
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)' R sl -> ptr_buff
            i2c.stop{}                          ' P
        other:
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes from ptr_buff to device
    case reg_nr
        $09, $0a, $0e, $0f, $11..$15, $17..$1d, $1f..$21, $23..$31, $3f..$44,{
        } $52, $54..$5d, $5f..$78:
            cmd_pkt.byte[0] := _slave_addr
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}                         ' S
            i2c.wrblock_lsbf(@cmd_pkt, 2)       ' SL|W, reg_nr
            i2c.wrblock_msbf(ptr_buff, nr_bytes)' W ptr_buff -> sl
            i2c.stop{}                          ' P
        other:
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
