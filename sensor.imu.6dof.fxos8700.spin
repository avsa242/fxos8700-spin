{
    --------------------------------------------
    Filename: sensor.imu.6dof.fxos8700.spin
    Author: Jesse Burt
    Description: Driver for the FXOS8700 6DoF IMU
    Copyright (c) 2022
    Started Sep 19, 2020
    Updated Nov 7, 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "sensor.accel.common.spinh"
#include "sensor.magnetometer.common.spinh"
#include "sensor.temp.common.spinh"

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

    long _accel_time_res
    byte _opmode_orig
    byte _RES
    byte _addr_bits

PUB null{}
' This is not a top-level object

PUB start{}
' Start using "standard" Propeller I2C pins and 100kHz, default slave address
'   NOTE: Starts with no reset pin defined
    startx(DEF_SCL, DEF_SDA, DEF_HZ, %00, -1)

PUB startx(SCL_PIN, SDA_PIN, I2C_FREQ, ADDR_BITS, RES_PIN): status
' Start using custom pins, I2C bus freq, slave address bits
'   NOTE: RES_PIN is optional; specify -1, if unused
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_FREQ =< core#I2C_MAX_FREQ
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_FREQ))
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

            if (dev_id{} == core#DEVID_RESP)
                defaults{}
                return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB stop{}
' Stop the driver
    i2c.deinit{}
    bytefill(@_opmode_orig, 0, 2)

PUB defaults{}
' Factory default settings
    reset{}

PUB preset_active{}
' Like factory defaults, but with the following changes:
'   Accelerometer + Magnetometer enabled
'   Active/measurement mode
    reset{}
    accel_opmode(ACTIVE)
    opmode(BOTH)
    accel_scale(2)
    accel_data_rate(50)
    mag_scale(12)

PUB preset_click_det{}
' Preset settings for click detection
    reset{}
    accel_data_rate(400)
    accel_scale(2)
    click_axis_ena(%111111)                     ' enable X, Y, Z single tap det
    click_set_thresh_x(1_575000)                ' X: 1.575g thresh
    click_set_thresh_y(1_575000)                ' Y: 1.575g
    click_set_thresh_z(2_650000)                ' Z: 2.650g
    click_set_time(50_000)
    click_set_latency(300_000)
    dbl_click_set_win(300_000)
    accel_int_mask(INT_PULSE)                   ' enable click/pulse interrupts
    accel_int_routing(INT_PULSE)                ' route click ints to INT1 pin
    accel_opmode(ACTIVE)

PUB preset_freefall{}
' Preset settings for free-fall detection
    reset{}
    accel_data_rate(400)
    accel_scale(2)
    freefall_time(30_000)                       ' 30_000us/30ms min time
    freefall_thresh(0_315000)                   ' 0.315g's
    freefall_axis_ena(%111)                     ' all axes
    accel_opmode(ACTIVE)
    accel_int_mask(INT_FFALL)                   ' enable free-fall interrupt
    accel_int_routing(INT_FFALL)                ' route free-fall ints to INT1

PUB dev_id{}: id
' Read device identification
'   Returns: $C7
    readreg(core#WHO_AM_I, 1, @id)

{ re-use code that's common to other NXP accelerometer drivers }
#include "sensor.accel.nxp.common.spinh"

PUB fifo_ena(state): curr_state
' Enable FIFO memory
'   Valid values: *FALSE (0), TRUE(1 or -1)
'   Any other value polls the chip and returns the current setting
    case ||(state)
        0, 1:
            fifo_mode(||(state))
        other:
            curr_state := 0
            return fifo_mode(-2)

PUB fifo_full{}: flag
' Flag indicating FIFO full/overflowed
'   Returns:
'       FALSE (0): FIFO not full
'       TRUE (-1): FIFO full/overflowed
    flag := 0
    readreg(core#F_STATUS, 1, @flag)
    return ((flag >> core#F_OVF) & 1) == 1

PUB fifo_mode(mode): curr_mode | fmode_bypass
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

    { FIFO must be disabled first to switch between active modes }
    if ((curr_mode >> core#F_MODE) & core#F_MODE_BITS) <> BYPASS
        writereg(core#F_SETUP, 1, @fmode_bypass)

    writereg(core#F_SETUP, 1, @mode)

PUB fifo_threshold(level): curr_lvl
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

    cache_opmode{}                               ' switch to stdby to mod regs
    writereg(core#F_SETUP, 1, @level)
    restore_opmode{}                             ' restore original opmode

PUB fifo_nr_unread{}: nr_samples
' Number of unread samples stored in FIFO
'   Returns: 0..32
    nr_samples := 0
    readreg(core#F_STATUS, 1, @nr_samples)
    return (nr_samples & core#F_CNT_BITS)

PUB mag_bias(x, y, z) | tmp[2]
' Read magnetometer calibration offset values
'   x, y, z: pointers to copy offsets to
    readreg(core#M_OFF_X_MSB, 6, @tmp)
    long[x] := ~~tmp.word[2]
    long[y] := ~~tmp.word[1]
    long[z] := ~~tmp.word[0]

PUB mag_set_bias(x, y, z) | tmp
' Write magnetometer calibration offset values
'   Valid values:
'       -16384..16383 (clamped to range)
    tmp.word[2] := x := (-16384 #> x <# 16383) << 1
    tmp.word[1] := y := (-16384 #> y <# 16383) << 1
    tmp.word[0] := z := (-16384 #> z <# 16383) << 1
    writereg(core#M_OFF_X_MSB, 6, @tmp)

PUB mag_data(mx, my, mz) | tmp[2]
' Read the Magnetometer output registers
    tmp := 0
    readreg(core#M_OUT_X_MSB, 6, @tmp)
    long[mx] := ~~tmp.word[2]
    long[my] := ~~tmp.word[1]
    long[mz] := ~~tmp.word[0]

PUB mag_data_overrun{}: flag
' Flag indicating magnetometer data has overrun
'   Returns:
'       TRUE (-1): data overrun
'       FALSE (0): no data overrun
    flag := 0
    readreg(core#M_DR_STATUS, 1, @flag)
    return ((flag >> core#ZYXOW) & 1) == 1

PUB mag_data_oversmp(ratio): curr_ratio
' Set oversampling ratio for magnetometer output data
'   Valid values: (dependent upon current MagDataRate())
'       2, 4, 8, 16, 32, 64, 128, 256, 512, 1024
'       (default value for each data rate indicated in below tables)
'   Any other value polls the chip and returns the current setting
    curr_ratio := 0
    readreg(core#M_CTRL_REG1, 1, @curr_ratio)
    case mag_data_rate(-2)
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

PUB mag_data_rate(rate): curr_rate
' Set magnetometer output data rate, in Hz
'   Valid values: 1(.5625), 6(.25), 12(.5), 50, 100, 200, 400, *800
'   Any other value polls the chip and returns the current setting
'   NOTE: If opmode() is BOTH (3), the set data rate will be halved
'       (chip limitation)
    curr_rate := accel_data_rate(rate)

PUB mag_data_rdy{}: flag
' Flag indicating new magnetometer data available
'   Returns TRUE (-1) if data ready, FALSE otherwise
    flag := 0
    readreg(core#M_DR_STATUS, 1, @flag)
    return ((flag & core#ZYX_DR) <> 0)

PUB mag_int{}: magintsrc
' Magnetometer interrupt source(s)
'   Returns: Interrupts that are currently asserted, as a bitmask
'       Bits: 210
'           2: Magnetic threshold interrupt
'           1: Magnetic vector-magnitude interrupt
'           0: Magnetic data-ready interrupt
    magintsrc := 0
    readreg(core#M_INT_SRC, 1, @magintsrc)

PUB mag_int_duration(cycles): curr_cyc
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

PUB mag_int_ena(state): curr_state
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

PUB mag_int_mask(mask): curr_mask
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

PUB mag_int_routing(mask): curr_mask
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

PUB mag_int_set_thresh_x(thresh)
' Set magnetometer interrupt threshold, X-axis
'   Valid values: 0..32_767000 (clamped to range)
    thresh := ((0 #> thresh <# 32_767000) / 1000)   ' LSB = 0.1uT or 0.001Gs
    writereg(core#M_THS_X_MSB, 2, @thresh)

PUB mag_int_set_thresh_y(thresh)
' Set magnetometer interrupt threshold, Y-axis
'   Valid values: 0..32_767000 (clamped to range)
    thresh := ((0 #> thresh <# 32_767000) / 1000)   ' LSB = 0.1uT or 0.001Gs
    writereg(core#M_THS_Y_MSB, 2, @thresh)

PUB mag_int_set_thresh_z(thresh)
' Set magnetometer interrupt threshold, Z-axis
'   Valid values: 0..32_767000 (clamped to range)
    thresh := ((0 #> thresh <# 32_767000) / 1000)   ' LSB = 0.1uT or 0.001Gs
    writereg(core#M_THS_Z_MSB, 2, @thresh)

PUB mag_int_thresh_x{}: thresh
' Get magnetometer interrupt X-axis threshold
'   Returns: micro-Gauss
    thresh := 0
    readreg(core#M_THS_X_MSB, 2, @thresh)
    return thresh * 1000

PUB mag_int_thresh_y{}: thresh
' Get magnetometer interrupt Y-axis threshold
'   Returns: micro-Gauss
    thresh := 0
    readreg(core#M_THS_X_MSB, 2, @thresh)
    return thresh * 1000

PUB mag_int_thresh_z{}: thresh
' Get magnetometer interrupt Z-axis threshold
'   Returns: micro-Gauss
    thresh := 0
    readreg(core#M_THS_X_MSB, 2, @thresh)
    return thresh * 1000

PUB mag_opmode(mode): curr_mode 'TODO
' Set magnetometer operating mode
'   Valid values:
'   Any other value polls the chip and returns the current setting
    curr_mode := 0

PUB mag_scale(scale): curr_scl
' Set magnetometer full-scale range, in Gauss
'   Valid values: N/A (fixed at 12Gs, 1200uT)
'   Returns: 12
'   NOTE: For API-compatibility only
    longfill(@_mres, MRES_GAUSS, MAG_DOF)
    return 12

PUB mag_thresh_int{}: int_src
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
    int_src := 0
    readreg(core#M_THS_SRC, 1, @int_src)

PUB opmode(mode): curr_mode
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

PUB reset{} | tmp
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

PUB sys_mode{}: sysmod 'XXX temporary
' Read current system mode
'   STDBY, ACTIVE, SLEEP
    sysmod := 0
    readreg(core#SYSMOD_REG, 1, @sysmod)
    return (sysmod & core#SYSMOD_BITS)

PUB temp_data{}: temp
' Read chip temperature
'   Returns: Temperature in hundredths of a degree Celsius (1000 = 10.00 deg C)
'   NOTE: OpMode() must be set to MAG (1) or BOTH (3) to read data from
'       the temperature sensor
'   NOTE: Output data rate is unaffected by accel_data_rate() or
'       MagDataRate() settings
    temp := 0
    readreg(core#TEMP, 1, @temp)

PUB temp_word2deg(adc_word): temp
' Convert ADC word to temperature in degrees of chosen scale
    temp := (adc_word * 0_96)
    case _temp_scale
        C:
            return
        F:
            return ((temp * 9_00) / 5_00) + 32_00
        K:
            return (temp + 273_15)
        other:
            return FALSE

PUB temp_data_rdy{}: flag
' Flag indicating new temperature sensor data available
'   Returns: TRUE (-1)
'   NOTE: For API compatibility only
    return TRUE

PRI cache_opmode{}
' Store the current operating mode, and switch to standby if different
'   (required for modifying some registers)
    _opmode_orig := accel_opmode(-2)
    if _opmode_orig <> STDBY                    ' must be in standby to change
        accel_opmode(STDBY)                      '   control regs

PRI restore_opmode{}
' Restore original operating mode
    if _opmode_orig <> STDBY                    ' restore original opmode
        accel_opmode(_opmode_orig)

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
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

PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
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

