library ieee;
use ieee.std_logic_1164.all;

library nios;
use nios.nios;

entity tp_nios_v is
    port (
        i_clk     : in    std_logic;
        i_rst_n   : in    std_logic;

        o_led     : out   std_logic_vector(9 downto 0);

        -- Lignes I2C vers l'accéléromètre
        io_i2c_scl : inout std_logic;
        io_i2c_sda : inout std_logic;

        -- Pins annexes du module ADXL345
        o_i2c_ncs  : out   std_logic;
        o_i2c_sdo  : out   std_logic
    );
end entity tp_nios_v;

architecture rtl of tp_nios_v is

    signal s_i2c_scl_in : std_logic;
    signal s_i2c_sda_in : std_logic;
    signal s_i2c_scl_oe : std_logic;
    signal s_i2c_sda_oe : std_logic;

begin

    -- Instance du système Platform Designer (nom : nios)
    nios0 : entity nios.nios
        port map (
            clk_clk                           => i_clk,
            reset_reset_n                     => i_rst_n,
            pio_0_external_connection_export  => o_led,

            i2c_0_i2c_serial_sda_in           => s_i2c_sda_in,
            i2c_0_i2c_serial_scl_in           => s_i2c_scl_in,
            i2c_0_i2c_serial_sda_oe           => s_i2c_sda_oe,
            i2c_0_i2c_serial_scl_oe           => s_i2c_scl_oe
        );

    s_i2c_scl_in <= io_i2c_scl;
    io_i2c_scl   <= '0' when s_i2c_scl_oe = '1' else 'Z';

    s_i2c_sda_in <= io_i2c_sda;
    io_i2c_sda   <= '0' when s_i2c_sda_oe = '1' else 'Z';

   
    o_i2c_ncs <= '1'; 
    o_i2c_sdo <= '0';  

end architecture rtl;
