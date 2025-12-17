library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;
use pll.all;

entity telecran is
    port (
        -- FPGA
        i_clk_50: in std_logic;

        -- HDMI
        io_hdmi_i2c_scl         : inout std_logic; 
        io_hdmi_i2c_sda         : inout std_logic; 
        o_hdmi_tx_clk           : out std_logic; 
        o_hdmi_tx_d             : out std_logic_vector(23 downto 0);
        o_hdmi_tx_de            : out std_logic; 
        o_hdmi_tx_hs            : out std_logic; 
        i_hdmi_tx_int           : in std_logic; 
        o_hdmi_tx_vs            : out std_logic; 

        -- KEYs
        i_rst_n : in std_logic; 
        
        -- LEDs
        o_leds : out std_logic_vector(9 downto 0);
        o_de10_leds : out std_logic_vector(7 downto 0); 

        -- Encodeurs
        i_left_ch_a : in std_logic;
        i_left_ch_b : in std_logic; 
        i_left_pb   : in std_logic; 
        i_right_ch_a : in std_logic; 
        i_right_ch_b : in std_logic; 
        i_right_pb   : in std_logic 
    );
end entity telecran;

architecture rtl of telecran is

    -- Déclarations des composants
    component I2C_HDMI_Config 
        port (
            iCLK : in std_logic;
            iRST_N : in std_logic;
            I2C_SCLK : out std_logic;
            I2C_SDAT : inout std_logic;
            HDMI_TX_INT  : in std_logic
        );
     end component;
    
    component pll 
        port (
            refclk : in std_logic;
            rst : in std_logic;
            outclk_0 : out std_logic;
            locked : out std_logic
        );
    end component;
    
    component encoder_manager 
        port (
            i_clk        : in  std_logic;
            i_rst_n      : in  std_logic;
            i_left_ch_a  : in  std_logic;
            i_left_ch_b  : in  std_logic;
            i_left_pb    : in  std_logic;
            o_coord_x    : out unsigned(9 downto 0);
            i_right_ch_a : in  std_logic;
            i_right_ch_b : in  std_logic;
            i_right_pb   : in  std_logic;
            o_coord_y    : out unsigned(9 downto 0)
        );
    end component;

    component hdmi_controler
        port (
            i_clk            : in  std_logic;
            i_rst_n          : in  std_logic;
            o_hdmi_hs        : out std_logic;
            o_hdmi_vs        : out std_logic;
            o_hdmi_de        : out std_logic;
            o_pixel_en       : out std_logic;
            o_pixel_address  : out natural;
            o_x_counter      : out natural;
            o_y_counter      : out natural
        );
    end component;

    component dpram 
        generic (
            mem_size    : natural := 720 * 480;
            data_width  : natural := 8
        );
        port (   
            i_clk_a     : in std_logic;
            i_clk_b     : in std_logic;
            i_data_a    : in std_logic_vector(data_width-1 downto 0);
            i_data_b    : in std_logic_vector(data_width-1 downto 0);
            i_addr_a    : in natural range 0 to mem_size-1;
            i_addr_b    : in natural range 0 to mem_size-1;
            i_we_a      : in std_logic := '1';
            i_we_b      : in std_logic := '1';
            o_q_a       : out std_logic_vector(data_width-1 downto 0);
            o_q_b       : out std_logic_vector(data_width-1 downto 0)
       );
    end component;

    -- Signaux internes
    signal s_clk_27 : std_logic; 
    signal s_rst_n  : std_logic; 
    signal s_coord_x : unsigned(9 downto 0);
    signal s_coord_y : unsigned(9 downto 0); 
    signal s_pixel_address : natural;
    signal s_pixel_data    : std_logic_vector(7 downto 0);
    
    -- Signaux pour l'effacement
    signal r_erase_active : std_logic := '0';
    signal r_erase_addr   : natural range 0 to (720 * 480) - 1 := 0;
    signal s_mux_addr_a   : natural range 0 to (720 * 480) - 1;
    signal s_mux_data_a   : std_logic_vector(7 downto 0);

begin
    o_de10_leds   <= (others => '0'); 
    o_hdmi_tx_clk <= s_clk_27;

    -- Instanciation PLL 
    pll0 : component pll 
        port map (
            refclk   => i_clk_50,
            rst      => not(i_rst_n),
            outclk_0 => s_clk_27,
            locked   => s_rst_n
        );

    -- Config HDMI 
    conf : component I2C_HDMI_Config 
        port map (
            iCLK        => i_clk_50,
            iRST_N      => i_rst_n,
            I2C_SCLK    => io_hdmi_i2c_scl,
            I2C_SDAT    => io_hdmi_i2c_sda,
            HDMI_TX_INT => i_hdmi_tx_int
        );

    -- Gestionnaire d'encodeurs 
    encs : component encoder_manager
        port map (
            i_clk        => i_clk_50,
            i_rst_n      => i_rst_n,
            i_left_ch_a  => i_left_ch_a,
            i_left_ch_b  => i_left_ch_b,
            i_left_pb    => i_left_pb,
            o_coord_x    => s_coord_x,
            i_right_ch_a => i_right_ch_a,
            i_right_ch_b => i_right_ch_b,
            i_right_pb   => i_right_pb,
            o_coord_y    => s_coord_y
        );

    -- Contrôleur HDMI
    hdmi_ctrl : component hdmi_controler
        port map (
            i_clk           => s_clk_27,
            i_rst_n         => s_rst_n,
            o_hdmi_hs       => o_hdmi_tx_hs,
            o_hdmi_vs       => o_hdmi_tx_vs,
            o_hdmi_de       => o_hdmi_tx_de,
            o_pixel_en      => open,
            o_pixel_address => s_pixel_address,
            o_x_counter     => open,
            o_y_counter     => open
        );

    -- Automate d'effacement (Reset de la RAM)
    process(i_clk_50, i_rst_n)
    begin
        if i_rst_n = '0' then
            r_erase_active <= '0';
            r_erase_addr   <= 0;
        elsif rising_edge(i_clk_50) then
            if i_left_pb = '0' then -- Bouton pressé
                r_erase_active <= '1';
                r_erase_addr   <= 0;
            elsif r_erase_active = '1' then
                if r_erase_addr = (720 * 480) - 1 then
                    r_erase_active <= '0';
                else
                    r_erase_addr <= r_erase_addr + 1;
                end if;
            end if;
        end if;
    end process;

    -- Multiplexeur pour l'écriture Port A
    s_mux_addr_a <= r_erase_addr when r_erase_active = '1' else 
                    (to_integer(s_coord_x) + (to_integer(s_coord_y) * 720));
    s_mux_data_a <= x"00" when r_erase_active = '1' else x"FF";

    -- Framebuffer DPRAM
    U_FrameBuffer : dpram
        port map (
            i_clk_a  => i_clk_50,
            i_clk_b  => s_clk_27,
            i_addr_a => s_mux_addr_a,
            i_data_a => s_mux_data_a,
            i_we_a   => '1',
            o_q_a    => open,
            i_addr_b => s_pixel_address,
            i_data_b => (others => '0'),
            i_we_b   => '0',
            o_q_b    => s_pixel_data
        );

    -- Sortie HDMI : Blanc si pixel mémorisé (x"FF"), sinon Noir
    o_hdmi_tx_d <= (others => '1') when s_pixel_data = x"FF" else (others => '0');

    -- Debug LEDs 
    o_leds <= std_logic_vector(s_coord_x);

end architecture rtl;