library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hdmi_controler is
    generic (
        h_res  : positive := 720; -- Résolution horizontale active
        v_res  : positive := 480; -- Résolution verticale active
        h_sync : positive := 61;  -- Timing Sync H
        h_fp   : positive := 58;  -- Front Porch H
        h_bp   : positive := 18;  -- Back Porch H
        v_sync : positive := 5;   -- Timing Sync V
        v_fp   : positive := 30;  -- Front Porch V
        v_bp   : positive := 9    -- Back Porch V
    );
    port (
        i_clk            : in  std_logic;
        i_rst_n          : in  std_logic;
        -- Vers composant ADV7513
        o_hdmi_hs        : out std_logic;
        o_hdmi_vs        : out std_logic;
        o_hdmi_de        : out std_logic;
        -- Vers générateur de pixels
        o_pixel_en       : out std_logic;
        o_pixel_address  : out natural;
        o_x_counter      : out natural;
        o_y_counter      : out natural
    );
end entity;

architecture rtl of hdmi_controler is
    -- Constantes de calcul des limites
    constant h_start : natural := h_sync + h_fp;
    constant h_end   : natural := h_start + h_res;
    constant h_total : natural := h_end + h_bp;

    constant v_start : natural := v_sync + v_fp;
    constant v_end   : natural := v_start + v_res;
    constant v_total : natural := v_end + v_bp;

    -- Registres internes
    signal r_h_count  : natural range 0 to h_total;
    signal r_v_count  : natural range 0 to v_total;
    signal r_h_active : std_logic;
    signal r_v_active : std_logic;
    
    -- Signal interne pour corriger l'erreur de lecture de sortie (Error 10309)
    signal r_pixel_address : natural;

begin

    -- Synchro Horizontale : Gère r_h_count, o_hdmi_hs et r_h_active
    process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            r_h_count  <= 0;
            o_hdmi_hs  <= '1';
            r_h_active <= '0';
        elsif rising_edge(i_clk) then
            -- Compteur H de 0 à h_total
            if r_h_count = h_total then
                r_h_count <= 0;
            else
                r_h_count <= r_h_count + 1;
            end if;

            -- Signal HS (Actif bas selon r_h_count)
            if r_h_count >= h_sync and r_h_count /= h_total then
                o_hdmi_hs <= '1';
            else
                o_hdmi_hs <= '0';
            end if;

            -- Registre h_active
            if r_h_count = h_start then
                r_h_active <= '1';
            elsif r_h_count = h_end then
                r_h_active <= '0';
            end if;
        end if;
    end process;

    -- Synchro Verticale : Incrémenté seulement à la fin d'une ligne H
    process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            r_v_count  <= 0;
            o_hdmi_vs  <= '1';
            r_v_active <= '0';
        elsif rising_edge(i_clk) then
            if r_h_count = h_total then
                -- Compteur V de 0 à v_total
                if r_v_count = v_total then
                    r_v_count <= 0;
                else
                    r_v_count <= r_v_count + 1;
                end if;

                -- Signal VS
                if r_v_count >= v_sync and r_v_count /= v_total then
                    o_hdmi_vs <= '1';
                else
                    o_hdmi_vs <= '0';
                end if;

                -- Registre v_active
                if r_v_count = v_start then
                    r_v_active <= '1';
                elsif r_v_count = v_end then
                    r_v_active <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Data Enable (o_hdmi_de)
    process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            o_hdmi_de <= '0';
        elsif rising_edge(i_clk) then
            o_hdmi_de <= r_h_active and r_v_active;
        end if;
    end process;

    -- Générateur d'adresses et coordonnées
    process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            o_pixel_en      <= '0';
            r_pixel_address <= 0;
            o_x_counter     <= 0;
            o_y_counter     <= 0;
        elsif rising_edge(i_clk) then
            o_pixel_en <= r_h_active and r_v_active;

            if (r_h_active = '1' and r_v_active = '1') then
                -- Coordonnées relatives à la zone active (0,0 en haut à gauche)
                o_x_counter <= r_h_count - h_start;
                o_y_counter <= r_v_count - v_start;
                
                -- Adresse linéaire de 0 à (h_res * v_res) - 1
                if r_h_count = h_end and r_v_count = v_end then
                    r_pixel_address <= 0;
                else
                    r_pixel_address <= r_pixel_address + 1;
                end if;
            end if;
        end if;
    end process;

    -- Affectation finale de l'adresse
    o_pixel_address <= r_pixel_address;

end architecture;