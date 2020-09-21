{
    --------------------------------------------
    Filename: core.con.fxos8700.spin
    Author: Jesse Burt
    Description: Low-level constants
    Copyright (c) 2020
    Started Sep 19, 2020
    Updated Sep 20, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SCK_MAX_FREQ        = 1_000_000
    I2C_MAX_FREQ        = 400_000

' Slave address options
'   Unfortunately, these aren't mapped logically in the chip, so
'   here are some constants to use, instead
    SLAVE_ADDR          = $1E << 1                      ' %00
    SLAVE_ADDR_1E       = SLAVE_ADDR                    ' %00 (default)
    SLAVE_ADDR_1D       = $1D << 1                      ' %01
    SLAVE_ADDR_1C       = $1C << 1                      ' %10
    SLAVE_ADDR_1F       = $1F << 1                      ' %11

' SPI R/W bit (7)
    R                   = 0
    W                   = 1 << 7

    TPOR                = 1000                          ' uSec

' Register definitions
    STATUS              = $00
        ZYXOW           = 7
        ZOW             = 6
        YOW             = 5
        XOW             = 4
        ZYXDR           = 3
        ZDR             = 2
        YDR             = 1
        XDR             = 0
        ZYXOW_BITS      = %111
        ZYXDR_BITS      = %111

    OUT_X_MSB           = $01
    OUT_X_LSB           = $02
    OUT_Y_MSB           = $03
    OUT_Y_LSB           = $04
    OUT_Z_MSB           = $05
    OUT_Z_LSB           = $06

'$07, $08 RESERVED

    F_SETUP             = $09
    F_SETUP_MASK        = $FF
        F_MODE          = 6
        F_WMRK          = 0
        F_MODE_BITS     = %11
        F_WMRK_BITS     = %111111
        F_MODE_MASK     = (F_MODE_BITS << F_MODE) ^ F_SETUP_MASK
        F_WMRK_MASK     = F_WMRK_BITS ^ F_SETUP_MASK

    TRIG_CFG            = $0A
    SYSMOD_REG          = $0B
    SYSMOD_REGMASK      = $FF
        FGERR           = 7
        FGT             = 2
        SYSMOD          = 0
        FGT_BITS        = %11111
        SYSMOD_BITS     = %11
        FGERR_MASK      = (1 << FGERR) ^ SYSMOD_REGMASK
        FGT_MASK        = (FGT_BITS << FGT) ^ SYSMOD_REGMASK
        SYSMOD_MASK     = SYSMOD_BITS ^ SYSMOD_REGMASK

    INT_SOURCE          = $0C

    WHO_AM_I            = $0D
        DEVID_RESP      = $C7

    XYZ_DATA_CFG        = $0E
    XYZ_DATA_CFG_MASK   = $13
        HPF_OUT         = 4
        FS              = 0
        FS_BITS         = %11
        HPF_OUT_MASK    = (1 << HPF_OUT) ^ XYZ_DATA_CFG_MASK
        FS_MASK         = FS_BITS ^ XYZ_DATA_CFG_MASK

    HP_FILTER_CUTOFF    = $0F
    PL_STATUS           = $10
    PL_CFG              = $11
    PL_COUNT            = $12
    PL_BF_ZCOMP         = $13
    PL_THS_REG          = $14
    A_FFMT_CFG          = $15
    A_FFMT_SRC          = $16
    A_FFMT_THS          = $17
    A_FFMT_COUNT        = $18

' $19..$1C RESERVED

    TRANSIENT_CFG       = $1D
    TRANSIENT_SRC       = $1E
    TRANSIENT_THS       = $1F
    TRANSIENT_COUNT     = $20
    PULSE_CFG           = $21
    PULSE_SRC           = $22
    PULSE_THSX          = $23
    PULSE_THSY          = $24
    PULSE_THSZ          = $25
    PULSE_TMLT          = $26
    PULSE_LTCY          = $27
    PULSE_WIND          = $28
    ASLP_COUNT          = $29

    CTRL_REG1           = $2A
    CTRL_REG1_MASK      = $FF
        ASLP_RATE       = 6
        DR              = 3
        LNOISE          = 2
        F_READ          = 1
        ACTIVE          = 0
        ASLP_RATE_BITS  = %11
        DR_BITS         = %111
        ASLP_RATE_MASK  = (ASLP_RATE_BITS << ASLP_RATE) ^ CTRL_REG1_MASK
        DR_MASK         = (DR_BITS << DR) ^ CTRL_REG1_MASK
        LNOISE_MASK     = (1 << LNOISE) ^ CTRL_REG1_MASK
        F_READ_MASK     = (1 << F_READ) ^ CTRL_REG1_MASK
        ACTIVE_MASK     = ASLP_RATE_BITS ^ CTRL_REG1_MASK

    CTRL_REG2           = $2B
    CTRL_REG3           = $2C
    CTRL_REG4           = $2D
    CTRL_REG5           = $2E
    OFF_X               = $2F
    OFF_Y               = $30
    OFF_Z               = $31
    M_DR_STATUS         = $32
    M_OUT_X_MSB         = $33
    M_OUT_X_LSB         = $34
    M_OUT_Y_MSB         = $35
    M_OUT_Y_LSB         = $36
    M_OUT_Z_MSB         = $37
    M_OUT_Z_LSB         = $38
    CMP_X_MSB           = $39
    CMP_X_LSB           = $3A
    CMP_Y_MSB           = $3B
    CMP_Y_LSB           = $3C
    CMP_Z_MSB           = $3D
    CMP_Z_LSB           = $3E
    M_OFF_X_MSB         = $3F
    M_OFF_X_LSB         = $40
    M_OFF_Y_MSB         = $41
    M_OFF_Y_LSB         = $42
    M_OFF_Z_MSB         = $43
    M_OFF_Z_LSB         = $44
    MAX_X_MSB           = $45
    MAX_X_LSB           = $46
    MAX_Y_MSB           = $47
    MAX_Y_LSB           = $48
    MAX_Z_MSB           = $49
    MAX_Z_LSB           = $4A
    MIN_X_MSB           = $4B
    MIN_X_LSB           = $4C
    MIN_Y_MSB           = $4D
    MIN_Y_LSB           = $4E
    MIN_Z_MSB           = $4F
    MIN_Z_LSB           = $50
    TEMP                = $51
    M_THS_CFG           = $52
    M_THS_SRC           = $53
    M_THS_X_MSB         = $54
    M_THS_X_LSB         = $55
    M_THS_Y_MSB         = $56
    M_THS_Y_LSB         = $57
    M_THS_Z_MSB         = $58
    M_THS_Z_LSB         = $59
    M_THS_COUNT         = $5A
    M_CTRL_REG1         = $5B
    M_CTRL_REG2         = $5C
    M_CTRL_REG3         = $5D
    M_INT_SRC           = $5E
    A_VECM_CFG          = $5F
    A_VECM_THS_MSB      = $60
    A_VECM_THS_LSB      = $61
    A_VECM_CNT          = $62
    A_VECM_INITX_MSB    = $63
    A_VECM_INITX_LSB    = $64
    A_VECM_INITY_MSB    = $65
    A_VECM_INITY_LSB    = $66
    A_VECM_INITZ_MSB    = $67
    A_VECM_INITZ_LSB    = $68
    M_VECM_CFG          = $69
    M_VECM_THS_MSB      = $6A
    M_VECM_THS_LSB      = $6B
    M_VECM_CNT          = $6C
    M_VECM_INITX_MSB    = $6D
    M_VECM_INITX_LSB    = $6E
    M_VECM_INITY_MSB    = $6F
    M_VECM_INITY_LSB    = $70
    M_VECM_INITZ_MSB    = $71
    M_VECM_INITZ_LSB    = $72
    A_FFMT_THS_X_MSB    = $73
    A_FFMT_THS_X_LSB    = $74
    A_FFMT_THS_Y_MSB    = $75
    A_FFMT_THS_Y_LSB    = $76
    A_FFMT_THS_Z_MSB    = $77
    A_FFMT_THS_Z_LSB    = $78

' $79 RESERVED

#ifndef __propeller2__
PUB Null
'' This is not a top-level object
#endif
