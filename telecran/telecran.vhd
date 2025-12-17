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
        i_left_pb : in std_logic; 
        i_right_ch_a : in std_logic; 
        i_right_ch_b : in std_logic; 
        i_right_pb : in std_logic 
    );
end entity telecran;

architecture rtl of telecran is

    -- Composants internes
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

    -- Signaux de synchronisation et horloges
    signal s_clk_27 : std_logic; 
    signal s_rst_n  : std_logic; 
    
    -- Signaux du contrôleur HDMI (balayage en temps réel)
    signal s_x_counter : natural;
    signal s_y_counter : natural;

    -- Signaux des encodeurs (position mémorisée)
    signal s_coord_x : unsigned(9 downto 0); 
    signal s_coord_y : unsigned(9 downto 0); 

begin
    -- Affectations des sorties système
    o_de10_leds   <= (others => '0'); 
    o_hdmi_tx_clk <= s_clk_27;

    -- PLL : Génération de l'horloge 27MHz pour le HDMI 
    pll0 : component pll 
        port map (
            refclk   => i_clk_50, 
            rst      => not(i_rst_n), 
            outclk_0 => s_clk_27, 
            locked   => s_rst_n 
        );

    -- Configuration I2C pour l'ADV7513 
    I2C_HDMI_Config0 : component I2C_HDMI_Config 
        port map (
            iCLK        => i_clk_50, 
            iRST_N      => i_rst_n, 
            I2C_SCLK    => io_hdmi_i2c_scl, 
            I2C_SDAT    => io_hdmi_i2c_sda, 
            HDMI_TX_INT => i_hdmi_tx_int 
        );

    -- Contrôleur HDMI (Génère la synchro et les compteurs de pixels)
    U_HDMI_Driver : component hdmi_controler
        port map (
            i_clk           => s_clk_27,
            i_rst_n         => s_rst_n,
            o_hdmi_hs       => o_hdmi_tx_hs,
            o_hdmi_vs       => o_hdmi_tx_vs,
            o_hdmi_de       => o_hdmi_tx_de,
            o_pixel_en      => open,
            o_pixel_address => open,
            o_x_counter     => s_x_counter,
            o_y_counter     => s_y_counter
        );

    -- Gestionnaire d'encodeurs (Récupère la position X/Y souhaitée) 
    U_Encoder_Manager: component encoder_manager
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

    -- Logique de sortie HDMI : Dégradé de couleur basé sur la position du balayage
    -- On convertit les compteurs natural en vecteurs 8 bits (tronqués à 256)
    o_hdmi_tx_d(23 downto 16) <= std_logic_vector(to_unsigned(s_x_counter, 8)); 
    o_hdmi_tx_d(15 downto 8)  <= std_logic_vector(to_unsigned(s_y_counter, 8));
    o_hdmi_tx_d(7 downto 0)   <= (others => '0');

    -- Debug LEDs : Affiche la valeur binaire de la coordonnée X de l'encodeur 
    o_leds <= std_logic_vector(s_coord_x);

end architecture rtl;