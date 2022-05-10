{
    --------------------------------------------
    Filename: sensor.imu.6dof.fxos8700.i2c.spin
    Author: Jesse Burt
    Description: Driver for the FXOS8700 6DoF IMU
    Copyright (c) 2022
    Started Sep 19, 2020
    Updated May 10, 2021
    See end of file for terms of use.
    --------------------------------------------
}
#include "sensor.imu.common.spinh"

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

' Scales and data rates used during calibration/bias/offset process
    CAL_XL_SCL      = 2
    CAL_G_SCL       = 0
    CAL_M_SCL       = 12
    CAL_XL_DR       = 200
    CAL_G_DR        = 0
    CAL_M_DR        = CAL_XL_DR                 ' locked to accel data rate

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
    SLEEP           = 2

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

' Accelerometer power modes
    NORMAL          = 0
    LONOISE_LOPWR   = 1
    HIGHRES         = 2
    LOPWR           = 3

' Orientation
    PORTUP_FR       = %000
    PORTUP_BK       = %001
    PORTDN_FR       = %010
    PORTDN_BK       = %011
    LANDRT_FR       = %100
    LANDRT_BK       = %101
    LANDLT_FR       = %110
    LANDLT_BK       = %111

' Wake on interrupt sources
    WAKE_TRANS      = 1 << 4
    WAKE_ORIENT     = 1 << 3
    WAKE_PULSE      = 1 << 2
    WAKE_FFALL      = 1 << 1
    WAKE_VECM       = 1

' Interrupt active state
    LOW             = 0
    HIGH            = 1

OBJ

    i2c     : "com.i2c"                         ' PASM I2C engine
    core    : "core.con.fxos8700"               ' HW-specific constants
    time    : "time"                            ' timekeeping methods

VAR

    long _ares, _abiasraw[ACCEL_DOF]
    long _mres[MAG_DOF], _mbiasraw[MAG_DOF]
    byte _addr_bits, _temp_scale
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
                %00: _addr_bits := core#SLAVE_ADDR_1E
                %01: _addr_bits := core#SLAVE_ADDR_1D
                %10: _addr_bits := core#SLAVE_ADDR_1C
                %11: _addr_bits := core#SLAVE_ADDR_1F
                other: _addr_bits := core#SLAVE_ADDR_1E

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
    reset{}

PUB Preset_Active{}
' Like factory defaults, but with the following changes:
'   Accelerometer + Magnetometer enabled
'   Active/measurement mode
    reset{}
    accelopmode(ACTIVE)
    opmode(BOTH)
    accelscale(2)
    acceldatarate(50)
    magscale(12)

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

PUB Preset_FreeFall{}
' Preset settings for free-fall detection
    reset{}
    acceldatarate(400)
    accelscale(2)
    freefalltime(30_000)                        ' 30_000us/30ms min time
    freefallthresh(0_315000)                    ' 0.315g's
    freefallaxisenabled(%111)                   ' all axes
    accelopmode(ACTIVE)
    intmask(INT_FFALL)                          ' enable free-fall interrupt
    introuting(INT_FFALL)                       ' route free-fall ints to INT1

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
            { scale ADC words down to bias reg range }
            bias_x /= 512
            bias_y /= 512
            bias_z /= 512
            tmp.byte[2] := bias_x := -128 #> bias_x <# 127
            tmp.byte[1] := bias_y := -128 #> bias_y <# 127
            tmp.byte[0] := bias_z := -128 #> bias_z <# 127
            cacheopmode{}                       ' switch to stdby to mod regs
            writereg(core#OFF_X, 3, @tmp)
            restoreopmode{}                     ' restore original opmode

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
    return ((flag & core#ZYX_OW) <> 0)

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

    rate := ((curr_rate & core#DR_MASK) | rate)
    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#CTRL_REG1, 1, @rate)
    restoreopmode{}                             ' restore original opmode

PUB AccelDataReady{}: flag
' Flag indicating new accelerometer data available
'   Returns TRUE (-1) if data ready, FALSE otherwise
    flag := 0
    readreg(core#STATUS, 1, @flag)
    return ((flag & core#ZYX_DR) <> 0)

PUB AccelHPFEnabled(state): curr_state
' Enable accelerometer data high-pass filter
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#XYZ_DATA_CFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#HPF_OUT
        other:
            return (((curr_state >> core#HPF_OUT) & 1) == 1)

    state := ((curr_state & core#HPF_OUT_MASK) | state)
    writereg(core#XYZ_DATA_CFG, 1, @state)

PUB AccelHPFreq(freq): curr_freq
' Set accelerometer data high-pass cutoff frequency, in milli-Hz
'   Valid values:
'   AccelPowerMode(): NORMAL
'   AccelDataRate():    800, 400    200     100     50, 12, 6, 1
'                       16_000      8_000   4_000   2_000
'                       8_000       4_000   2_000   1_000
'                       4_000       2_000   1_000   500
'                       2_000       1_000   500     250
'   AccelPowerMode(): LONOISE_LOPWR
'   AccelDataRate():    800, 400    200     100     50      12, 6, 1
'                       16_000      8_000   4_000   2_000   500
'                       8_000       4_000   2_000   1_000   250
'                       4_000       2_000   1_000   500     125
'                       2_000       1_000   500     250     63
'   AccelPowerMode(): HIGHRES
'   AccelDataRate():    All
'                       16_000
'                       8_000
'                       4_000
'                       2_000
'   AccelPowerMode(): LOPWR
'   AccelDataRate():    800     400     200     100     50      12, 6, 1
'                       16_000  8_000   4_000   2_000   1_000   250
'                       8_000   4_000   2_000   1_000   500     125
'                       4_000   2_000   1_000   500     250     63
'                       2_000   1_000   500     250     125     31
'   Any other value polls the chip and returns the current setting
    curr_freq := 0
    readreg(core#HP_FILT_CUTOFF, 1, @curr_freq)
    case accelpowermode(-2)
        NORMAL:
            case acceldatarate(-2)
                800, 400:
                    case freq
                        16_000, 8_000, 4_000, 2_000:
                            freq := lookdownz(freq: 16_000, 8_000, 4_000, 2_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 16_000, 8_000, 4_000, 2_000)
                200:
                    case freq
                        8_000, 4_000, 2_000, 1_000:
                            freq := lookdownz(freq: 8_000, 4_000, 2_000, 1_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 8_000, 4_000, 2_000, 1_000)
                100:
                    case freq
                        4_000, 2_000, 1_000, 500:
                            freq := lookdownz(freq: 4_000, 2_000, 1_000, 500)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 4_000, 2_000, 1_000, 500)
                50, 12, 6, 1:
                    case freq
                        2_000, 1_000, 500, 250:
                            freq := lookdownz(freq: 2_000, 1_000, 500, 250)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 2_000, 1_000, 500, 250)
        LONOISE_LOPWR:
            case acceldatarate(-2)
                800, 400:
                    case freq
                        16_000, 8_000, 4_000, 2_000:
                            freq := lookdownz(freq: 16_000, 8_000, 4_000, 2_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 16_000, 8_000, 4_000, 2_000)
                200:
                    case freq
                        8_000, 4_000, 2_000, 1_000:
                            freq := lookdownz(freq: 8_000, 4_000, 2_000, 1_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 8_000, 4_000, 2_000, 1_000)
                100:
                    case freq
                        4_000, 2_000, 1_000, 500:
                            freq := lookdownz(freq: 4_000, 2_000, 1_000, 500)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 4_000, 2_000, 1_000, 500)
                50:
                    case freq
                        2_000, 1_000, 500, 250:
                            freq := lookdownz(freq: 2_000, 1_000, 500, 250)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 2_000, 1_000, 500, 250)
                12, 6, 1:
                    case freq
                        500, 250, 125, 63:
                            freq := lookdownz(freq: 500, 250, 125, 63)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 500, 250, 125, 63)
        HIGHRES:
            case freq
                2_000, 4_000, 8_000, 16_000:
                    freq := lookdownz(freq: 16_000, 8_000, 4_000, 2_000)
        LOPWR:
            case acceldatarate(-2)
                800:
                    case freq
                        16_000, 8_000, 4_000, 2_000:
                            freq := lookdownz(freq: 16_000, 8_000, 4_000, 2_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 16_000, 8_000, 4_000, 2_000)
                400:
                    case freq
                        8_000, 4_000, 2_000, 1_000:
                            freq := lookdownz(freq: 8_000, 4_000, 2_000, 1_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 8_000, 4_000, 2_000, 1_000)
                200:
                    case freq
                        4_000, 2_000, 1_000, 500:
                            freq := lookdownz(freq: 4_000, 2_000, 1_000, 500)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 4_000, 2_000, 1_000, 500)
                100:
                    case freq
                        2_000, 1_000, 500, 250:
                            freq := lookdownz(freq: 2_000, 1_000, 500, 250)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 2_000, 1_000, 500, 250)
                50:
                    case freq
                        1_000, 500, 250, 125:
                            freq := lookdownz(freq: 1_000, 500, 250, 125)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 1_000, 500, 250, 125)
                12, 6, 1:
                    case freq
                        250, 125, 63, 31:
                            freq := lookdownz(freq: 250, 125, 63, 31)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 250, 125, 63, 31)
    freq := ((curr_freq & core#SEL_MASK) | freq)
    writereg(core#HP_FILT_CUTOFF, 1, @freq)

PUB AccelInt{}: flag 'TODO
' Flag indicating accelerometer interrupt asserted
'   Returns TRUE if interrupt asserted, FALSE if not
    flag := 0

PUB AccelLowNoiseMode(mode): curr_mode    'XXX tentatively named
' Set accelerometer low noise mode
'   Valid values:
'       NORMAL (0), LOWNOISE (1)
'   Any other value polls the chip and returns the current setting
'   NOTE: When mode is LOWNOISE, range is limited to +/- 4g
'       This also affects set interrupt thresholds
'       (i.e., values outside 4g would never be reached)
    curr_mode := 0
    readreg(core#CTRL_REG1, 1, @curr_mode)
    case mode
        0, 1:
            mode <<= core#LNOISE
        other:
            return ((curr_mode >> core#LNOISE) & 1)

    cacheopmode{}                               ' switch to stdby to mod regs
    mode := ((curr_mode & core#LNOISE_MASK) | mode)
    writereg(core#CTRL_REG1, 1, @mode)
    restoreopmode{}                             ' restore original opmode

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

    mode := ((curr_mode & core#ACTIVE_MASK) | mode)
    writereg(core#CTRL_REG1, 1, @mode)

PUB AccelPowerMode(mode): curr_mode ' XXX tentatively named
' Set accelerometer power mode/oversampling mode, when active
'   Valid values:
'       NORMAL (0): Normal
'       LONOISE_LOPWR (1): Low noise low power
'       HIGHRES (2): High resolution
'       LOPWR (3): Low power
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#CTRL_REG2, 1, @curr_mode)
    case mode
        NORMAL, LONOISE_LOPWR, HIGHRES, LOPWR:
        other:
            return curr_mode & core#MODS_BITS

    mode := ((curr_mode & core#MODS_MASK) | mode)

    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#CTRL_REG2, 1, @mode)
    restoreopmode{}                             ' restore original opmode

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

PUB AccelSelfTest(state): curr_state
' Enable accelerometer self-test
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   During self-test, the output data changes approximately as follows
'       (typ. values @ 4g full-scale)
'       X: +0.085g (44LSB * 1953 micro-g per LSB)
'       Y: +0.119g (61LSB * 1953 micro-g per LSB)
'       Z: +0.765g (392LSB * 1953 micro-g per LSB)
    curr_state := 0
    readreg(core#CTRL_REG2, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#ST
        other:
            return (((curr_state >> core#ST) & 1) == 1)

    cacheopmode{}
    state := ((curr_state & core#ST_MASK) | state)
    writereg(core#CTRL_REG2, 1, @state)
    restoreopmode{}

PUB AccelSleepPwrMode(mode): curr_mode
' Set accelerometer power mode/oversampling mode, when sleeping
'   Valid values:
'       NORMAL (0): Normal
'       LONOISE_LOPWR (1): Low noise low power
'       HIGHRES (2): High resolution
'       LOPWR (3): Low power
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#CTRL_REG2, 1, @curr_mode)
    case mode
        NORMAL, LONOISE_LOPWR, HIGHRES, LOPWR:
            mode <<= core#SMODS
        other:
            return ((curr_mode >> core#SMODS) & core#SMODS_BITS)

    cacheopmode{}
    mode := ((curr_mode & core#SMODS_MASK) | mode)
    writereg(core#CTRL_REG2, 1, @mode)
    restoreopmode{}

PUB AccelWord2G(accel_word): accel_g
' Convert accelerometer ADC word to g's
    return (accel_word * _ares)

PUB AutoSleep(state): curr_state
' Enable automatic transition to sleep state when inactive
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#CTRL_REG2, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#SLPE
        other:
            return (((curr_state >> core#SLPE) & 1) == 1)

    cacheopmode{}
    state := ((curr_state & core#SLPE_MASK) | state)
    writereg(core#CTRL_REG2, 1, @state)
    restoreopmode{}

PUB AutoSleepDataRate(rate): curr_rate
' Set accelerometer output data rate, in Hz, when in sleep mode
'   Valid values: 1, 6, 12, 50
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#CTRL_REG1, 1, @curr_rate)
    case rate
        1, 6, 12, 50:
            rate := lookdownz(rate: 50, 12, 6, 1) << core#ASLP_RATE
        other:
            curr_rate := ((curr_rate >> core#ASLP_RATE) & core#ASLP_RATE_BITS)
            return lookupz(curr_rate: 50, 12, 6, 1)

    cacheopmode{}
    rate := ((curr_rate & core#ASLP_RATE_MASK) | rate)
    writereg(core#CTRL_REG1, 1, @rate)
    restoreopmode{}

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

PUB Clicked{}: flag
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

    if opmode(-2) == BOTH                       ' if both sensors are enabled,
        time_res *= 2                           '   effective ODR is half, and
                                                '   timing-sensitive regs
                                                '   change proprotionately

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

    if opmode(-2) == BOTH                       ' if both sensors are enabled,
        time_res *= 2                           '   effective ODR is half, and
                                                '   timing-sensitive regs
                                                '   change proprotionately

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

    if opmode(-2) == BOTH                       ' if both sensors are enabled,
        time_res *= 2                           '   effective ODR is half, and
                                                '   timing-sensitive regs
                                                '   change proprotionately

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

    level := ((curr_lvl & core#F_WMRK_MASK) | level)

    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#F_SETUP, 1, @level)
    restoreopmode{}                             ' restore original opmode

PUB FIFOUnreadSamples: nr_samples
' Number of unread samples stored in FIFO
'   Returns: 0..32
    nr_samples := 0
    readreg(core#F_STATUS, 1, @nr_samples)
    return (nr_samples & core#F_CNT_BITS)

PUB FreeFallAxisEnabled(mask): curr_mask
' Enable free-fall detection, per axis mask
'   Valid values: %000..%111 (ZYX)
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#FFMT_CFG, 1, @curr_mask)
    case mask
        %000..%111:
            mask <<= core#FEFE
        other:
            return ((curr_mask >> core#FEFE) & core#FEFE_BITS)

    mask := ((curr_mask & core#FEFE_MASK) | mask)
    writereg(core#FFMT_CFG, 1, @mask)

PUB FreeFallThresh(thresh): curr_thr
' Set free-fall threshold, in micro-g's
'   Valid values: 0..8_001000 (0..8g's)
'   Any other value polls the chip and returns the current setting
    curr_thr := 0
    readreg(core#FFMT_THS, 1, @curr_thr)
    case thresh
        0..8_001000:
            thresh /= 0_063000
        other:
            return ((curr_thr & core#FF_THS_BITS) * 0_063000)

    thresh := ((curr_thr & core#FF_THS_MASK) | thresh)
    writereg(core#FFMT_THS, 1, @thresh)

PUB FreeFallTime(fftime): curr_time | odr, time_res, max_dur
' Set minimum time duration required to recognize free-fall, in microseconds
'   Valid values: 0..maximum in table below:
'                           AccelPowerMode():
'       AccelDataRate():    NORMAL     LONOISE_LOPWR   HIGHRES     LOPWR
'       800Hz               319_000    319_000         319_000     319_000
'       400                 638_000    638_000         638_000     638_000
'       200                 1_280      1_280           638_000     1_280
'       100                 2_550      2_550           638_000     2_550
'       50                  5_100      5_100           638_000     5_100
'       12                  5_100      20_400          638_000     20_400
'       6                   5_100      20_400          638_000     40_800
'       1                   5_100      20_400          638_000     40_800
'   Any other value polls the chip and returns the current setting
    odr := acceldatarate(-2)
    case accelpowermode(-2)
        NORMAL:
            time_res := 1_250 #> (1_000000/odr) <# 20_000
        LONOISE_LOPWR:
            time_res := 1_250 #> (1_000000/odr) <# 80_000
        HIGHRES:
            time_res := 1_250 #> (1_000000/odr) <# 2_500
        LOPWR:
            time_res := 1_250 #> (1_000000/odr) <# 160_000

    max_dur := (time_res * 255)
    if opmode(-2) == BOTH                       ' if both sensors are enabled,
        time_res *= 2                           '   effective ODR is half, and
                                                '   timing-sensitive regs
                                                '   change proprotionately

    case fftime
        0..max_dur:
            fftime /= time_res
            writereg(core#FFMT_CNT, 1, @fftime)
        other:
            curr_time := 0
            readreg(core#FFMT_CNT, 1, @curr_time)
            return (curr_time * time_res)

PUB GyroBias(x, y, z, rw)
' dummy method

PUB GyroData(x, y, z)
' dummy method

PUB GyroDataRate(rate)
' dummy method

PUB GyroDataReady{}
' dummy method

PUB GyroScale(scale)
' dummy method

PUB GyroWord2DPS(gyro_word)
' dummy method

PUB InactInt(mask): curr_mask
' Set inactivity interrupt mask
'   Valid values:
'       Bits [4..0]
'       4: Wake on transient interrupt
'       3: Wake on orientation interrupt
'       2: Wake on pulse/click/tap interrupt
'       1: Wake on free-fall/motion interrupt
'       0: Wake on vector-magnitude interrupt
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#CTRL_REG3, 1, @curr_mask)
    case mask
        %00000..%11111:
            mask <<= core#WAKE
        other:
            return ((curr_mask >> core#WAKE) & core#WAKE_BITS)

    cacheopmode{}
    mask := ((curr_mask & core#WAKE_MASK) | mask)
    writereg(core#CTRL_REG3, 1, @mask)
    restoreopmode{}

PUB InactTime(itime): curr_itime | max_dur, time_res
' Set inactivity time, in milliseconds
'   Valid values:
'       0..163_200 (AccelDataRate() == 1)
'       0..81_600 (AccelDataRate() == all other settings)
'   Any other value polls the chip and returns the current setting
'   NOTE: Setting this to 0 will generate an interrupt when the acceleration
'       measures less than that set with InactThresh()
    if acceldatarate(-2) == 1
        time_res := 640                         ' 640ms time step for 1Hz ODR
    else
        time_res := 320                         ' 320ms time step for others
    max_dur := (time_res * 255)                 ' calc max possible duration
    if opmode(-2) == BOTH                       ' if both sensors are enabled,
        time_res *= 2                           '   effective ODR is half, and
                                                '   timing-sensitive regs
                                                '   change proprotionately
    case itime
        0..max_dur:
            cacheopmode{}
            itime := (itime / time_res)
            writereg(core#ASLP_CNT, 1, @itime)
            restoreopmode{}
        other:
            curr_itime := 0
            readreg(core#ASLP_CNT, 1, @curr_itime)
            return (curr_itime * time_res)

PUB InFreeFall{}: flag
' Flag indicating device is in free-fall
'   Returns:
'       TRUE (-1): device is in free-fall
'       FALSE (0): device isn't in free-fall
    flag := 0
    readreg(core#FFMT_SRC, 1, @flag)
    return (((flag >> core#FEA) & 1) == 1)

PUB IntActiveState(state): curr_state
' Set interrupt pin active state/logic level
'   Valid values: LOW (0), HIGH (1)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#CTRL_REG3, 1, @curr_state)
    case state
        LOW, HIGH:
            state <<= core#IPOL
        other:
            return ((curr_state >> core#IPOL) & 1)

    cacheopmode{}
    state := ((curr_state & core#IPOL_MASK) | state)
    writereg(core#CTRL_REG3, 1, @state)
    restoreopmode{}

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
                    reg_nr := lookdownz(i: core#FFMT_SRC, core#PULSE_SRC, {
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

    ratio := ((curr_ratio & core#M_OS_MASK) | ratio)
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
    return ((flag & core#ZYX_DR) <> 0)

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
            writereg(core#M_THS_CNT, 1, @cycles)
        other:
            curr_cyc := 0
            readreg(core#M_THS_CNT, 1, @curr_cyc)
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

    state := ((curr_state & core#THS_INT_EN_MASK) | state)
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
    longfill(@_mres, MRES_GAUSS, MAG_DOF)
    return 12

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

    state := ((curr_state & core#THS_INT_EN_MASK) | state)
    writereg(core#M_THS_CFG, 1, @state)

PUB MagXWord2Gauss(mag_word): mag_gauss
' Convert magnetometer X-axis ADC word to Gauss
    return (mag_word * _mres[X_AXIS])

PUB MagYWord2Gauss(mag_word): mag_gauss
' Convert magnetometer Y-axis ADC word to Gauss
    return (mag_word * _mres[Y_AXIS])

PUB MagZWord2Gauss(mag_word): mag_gauss
' Convert magnetometer Z-axis ADC word to Gauss
    return (mag_word * _mres[Z_AXIS])

PUB MagXWord2Tesla(mag_word): mag_tesla
' Convert magnetometer X-axis ADC word to Teslas
    return (mag_word * _mres[X_AXIS]) / 10_000

PUB MagYWord2Tesla(mag_word): mag_tesla
' Convert magnetometer Y-axis ADC word to Teslas
    return (mag_word * _mres[Y_AXIS]) / 10_000

PUB MagZWord2Tesla(mag_word): mag_tesla
' Convert magnetometer Z-axis ADC word to Teslas
    return (mag_word * _mres[Z_AXIS]) / 10_000

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

    mode := ((curr_mode & core#M_HMS_MASK) | mode)
    writereg(core#M_CTRL_REG1, 1, @mode)

PUB Orientation{}: curr_or
' Current orientation
'   Returns:
'       %000: portrait-up, front-facing
'       %001: portrait-up, back-facing
'       %010: portrait-down, front-facing
'       %011: portrait-down, back-facing
'       %100: landscape-right, front-facing
'       %101: landscape-right, back-facing
'       %110: landscape-left, front-facing
'       %111: landscape-left, back-facing
    curr_or := 0
    readreg(core#PL_STATUS, 1, @curr_or)
    return (curr_or & core#LAPOBAFRO_BITS)

PUB OrientDetect(state): curr_state
' Enable orientation detection
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#PL_CFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#PL_EN
        other:
            return ((curr_state >> core#PL_EN) & 1) == 1

    state := ((curr_state & core#PL_EN_MASK) | state)
    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#PL_CFG, 1, @state)
    restoreopmode{}                             ' restore original opmode

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

PUB SysMode{}: sysmod 'XXX temporary
' Read current system mode
'   STDBY, ACTIVE, SLEEP
    sysmod := 0
    readreg(core#SYSMOD_REG, 1, @sysmod)
    return (sysmod & core#SYSMOD_BITS)

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

PUB TransCount(tcnt): curr_tcnt
' Set minimum number of debounced samples that must be greater than the
'   threshold set by TransThresh() to generate an interrupt
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
    case tcnt
        0..255:
            writereg(core#TRANSIENT_CNT, 1, @tcnt)
        other:
            curr_tcnt := 0
            readreg(core#TRANSIENT_CNT, 1, @curr_tcnt)

PUB TransAxisEnabled(axis_mask): curr_mask
' Enable transient acceleration detection, per mask
'   Valid values:
'       Bits [2..0]
'       2: Enable transient acceleration interrupt on Z-axis
'       1: Enable transient acceleration interrupt on Y-axis
'       0: Enable transient acceleration interrupt on X-axis
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#TRANSIENT_CFG, 1, @curr_mask)
    case axis_mask
        %000..%111:
            axis_mask <<= core#TEFE
        other:
            return ((curr_mask >> core#TEFE) & core#TEFE_MASK)

    cacheopmode{}
    axis_mask := ((curr_mask & core#TEFE_MASK) | axis_mask) | 1 << core#TELE
    writereg(core#TRANSIENT_CFG, 1, @axis_mask)
    restoreopmode{}

PUB TransInterrupt{}: int_src
' Read transient acceleration interrupt(s)
'   Bits [6..0]
'   6: One or more interrupts asserted
'   5: Z-axis transient interrupt
'   4: Z-axis transient interrupt polarity (0: positive, 1: negative)
'   3: Y-axis transient interrupt
'   2: Y-axis transient interrupt polarity (0: positive, 1: negative)
'   1: X-axis transient interrupt
'   0: X-axis transient interrupt polarity (0: positive, 1: negative)
    int_src := 0
    readreg(core#TRANSIENT_SRC, 1, @int_src)

PUB TransThresh(thr): curr_thr
' Set threshold for transient acceleration detection, in micro-g's
'   Valid values: 0..8_001000 (0..8gs)
'   Any other value polls the chip and returns the current setting
'   NOTE: If AccelPowerMode() == LOWNOISE, the maximum value is reduced
'       to 4g's (4_000000)
    curr_thr := 0
    readreg(core#TRANSIENT_THS, 1, @curr_thr)
    case thr
        0..8_001000:
            thr /= 0_063000
        other:
            return ((curr_thr & core#THS_BITS) * 0_063000)

    thr := ((curr_thr & core#THS_MASK) | thr)
    writereg(core#TRANSIENT_THS, 1, @thr)

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
            cmd_pkt.byte[0] := _addr_bits
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}                         ' S
            i2c.wrblock_lsbf(@cmd_pkt, 2)       ' SL|W, reg_nr
            i2c.start{}                         ' Sr
            i2c.write(_addr_bits | 1)           ' SL|R
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)' R sl -> ptr_buff
            i2c.stop{}                          ' P
        $00, $02, $04, $06, $09..$18, $1d..$32, $34, $36, $38, $3a, $3e..$78:
            cmd_pkt.byte[0] := _addr_bits
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}                         ' S
            i2c.wrblock_lsbf(@cmd_pkt, 2)       ' SL|W, reg_nr
            i2c.start{}                         ' Sr
            i2c.write(_addr_bits | 1)           ' SL|R
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)' R sl -> ptr_buff
            i2c.stop{}                          ' P
        other:
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes from ptr_buff to device
    case reg_nr
        $09, $0a, $0e, $0f, $11..$15, $17..$1d, $1f..$21, $23..$31, $3f..$44,{
        } $52, $54..$5d, $5f..$78:
            cmd_pkt.byte[0] := _addr_bits
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
