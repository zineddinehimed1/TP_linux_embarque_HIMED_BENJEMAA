#include <stdint.h>
#include <unistd.h>

#include "system.h"
#include "altera_avalon_pio_regs.h"
#include "altera_avalon_i2c.h"

/* --------- Réglages --------- */
#define NLEDS            10

#define ADXL345_ADDR     0x53

#define REG_DEVID        0x00
#define REG_POWER_CTL    0x2D
#define REG_DATA_FORMAT  0x31
#define REG_DATAX0       0x32

#define LEDS_ACTIVE_LOW  0

/* Seuils "retournement" sur Z (à ajuster si besoin) */
#define Z_FLIP_NEG_TH    (-200)   // en dessous => carte retournée
#define Z_FLIP_POS_TH    ( 200)   // au dessus  => carte normale

/* --------- Variables globales (Live Expressions) --------- */
volatile int16_t g_x = 0;
volatile int16_t g_y = 0;
volatile int16_t g_z = 0;

volatile int     g_idx = 0;
volatile uint8_t g_devid = 0;

volatile ALT_AVALON_I2C_STATUS_CODE g_i2c_status = ALT_AVALON_I2C_SUCCESS;

static inline uint32_t leds_apply_polarity(uint32_t v)
{
#if LEDS_ACTIVE_LOW
    return (~v) & ((1u << NLEDS) - 1u);
#else
    return v & ((1u << NLEDS) - 1u);
#endif
}

static inline void leds_write(uint32_t v)
{
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, leds_apply_polarity(v));
}

/* --------- Helpers I2C --------- */
static ALT_AVALON_I2C_STATUS_CODE i2c_write_reg(ALT_AVALON_I2C_DEV_t *dev, uint8_t reg, uint8_t val)
{
    uint8_t buf[2] = { reg, val };
    return alt_avalon_i2c_master_tx(dev, buf, 2, ALT_AVALON_I2C_NO_INTERRUPTS);
}

static ALT_AVALON_I2C_STATUS_CODE i2c_read_reg(ALT_AVALON_I2C_DEV_t *dev, uint8_t reg, uint8_t *val)
{
    return alt_avalon_i2c_master_tx_rx(dev, &reg, 1, val, 1, ALT_AVALON_I2C_NO_INTERRUPTS);
}

static ALT_AVALON_I2C_STATUS_CODE i2c_read_multi(ALT_AVALON_I2C_DEV_t *dev, uint8_t start_reg, uint8_t *rx, uint32_t n)
{
    return alt_avalon_i2c_master_tx_rx(dev, &start_reg, 1, rx, n, ALT_AVALON_I2C_NO_INTERRUPTS);
}

/* Niveau à bulle sur Y */
static int y_to_led_index(int16_t y)
{
    const int16_t min = -256;
    const int16_t max = +256;

    if (y <= min) return 0;
    if (y >= max) return NLEDS - 1;

    int32_t num = (int32_t)(y - min) * (NLEDS - 1);
    int32_t den = (max - min);
    int idx = (int)(num / den);

    if (idx < 0) idx = 0;
    if (idx > NLEDS - 1) idx = NLEDS - 1;
    return idx;
}

/* Animation d’effacement (wipe) */
static void wipe_animation(void)
{
    // 1) éteint progressivement de gauche à droite
    for (int i = 0; i < NLEDS; i++) {
        uint32_t mask = ((1u << NLEDS) - 1u) & ~((1u << (i + 1)) - 1u);
        leds_write(mask);
        usleep(50000);
    }

    // 2) petit flash
    for (int k = 0; k < 2; k++) {
        leds_write((1u << NLEDS) - 1u);
        usleep(80000);
        leds_write(0);
        usleep(80000);
    }
}

int main(void)
{
    ALT_AVALON_I2C_DEV_t *i2c_dev = alt_avalon_i2c_open(I2C_0_NAME);
    if (!i2c_dev) {
        while (1) {
            leds_write((1u << NLEDS) - 1u);
            usleep(200000);
            leds_write(0);
            usleep(200000);
        }
    }

    alt_avalon_i2c_master_target_set(i2c_dev, ADXL345_ADDR);

    g_i2c_status = i2c_read_reg(i2c_dev, REG_DEVID, (uint8_t*)&g_devid);
    if (g_i2c_status != ALT_AVALON_I2C_SUCCESS || g_devid != 0xE5) {
        while (1) {
            leds_write((1u << 0) | (1u << (NLEDS - 1)));
            usleep(150000);
            leds_write(0);
            usleep(150000);
        }
    }

    /* Init ADXL345 */
    i2c_write_reg(i2c_dev, REG_DATA_FORMAT, 0x08); // FULL_RES, +/-2g
    i2c_write_reg(i2c_dev, REG_POWER_CTL,   0x08); // Measure=1
    usleep(10000);

    /* Etat de “face up/down” avec hystérésis */
    int is_flipped = 0;

    while (1)
    {
        uint8_t rx[6];
        g_i2c_status = i2c_read_multi(i2c_dev, REG_DATAX0, rx, 6);

        if (g_i2c_status == ALT_AVALON_I2C_SUCCESS)
        {
            g_x = (int16_t)((rx[1] << 8) | rx[0]);
            g_y = (int16_t)((rx[3] << 8) | rx[2]);
            g_z = (int16_t)((rx[5] << 8) | rx[4]);

            /* Détection retournement via Z + hystérésis */
            if (!is_flipped && g_z < Z_FLIP_NEG_TH) {
                // Transition "normal" -> "retourné" : effacement !
                is_flipped = 1;
                wipe_animation();
            } else if (is_flipped && g_z > Z_FLIP_POS_TH) {
                // Reviens en position normale
                is_flipped = 0;
            }

            /* Affichage niveau à bulle (sur Y) */
            g_idx = y_to_led_index(g_y);
            leds_write(1u << g_idx);
        }
        else
        {
            leds_write(0);
        }

        usleep(30000);
    }
}
