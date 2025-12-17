library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity encoder_manager is
    port (
        i_clk   : in  std_logic;
        i_rst_n : in  std_logic;
        
        -- Encodeur GAUCHE (Contrôle X)
        i_left_ch_a : in std_logic;
        i_left_ch_b : in std_logic;
        i_left_pb   : in std_logic; -- Non utilisé pour la position (réservé pour un Reset local)
        o_coord_x   : out unsigned(9 downto 0); -- Coordonnée X (10 bits)
        
        -- Encodeur DROIT (Contrôle Y)
        i_right_ch_a : in std_logic;
        i_right_ch_b : in std_logic;
        i_right_pb   : in std_logic; -- Non utilisé pour la position
        o_coord_y    : out unsigned(9 downto 0)  -- Coordonnée Y (10 bits)
    );
end entity encoder_manager;

architecture rtl of encoder_manager is
    -- Paramètres des Coordonnées
    constant C_COORD_WIDTH : integer := 10;
    constant C_MAX_COORD   : natural := 1023; -- 2^10 - 1

    -- Registres des Coordonnées
    signal r_coord_x : unsigned(C_COORD_WIDTH - 1 downto 0) := (others => '0');
    signal r_coord_y : unsigned(C_COORD_WIDTH - 1 downto 0) := (others => '0');

    -- Signaux de Synchronisation (GAUCHE - X)
    signal r_A_sync_left : std_logic_vector(1 downto 0) := (others => '0');
    signal r_B_sync_left : std_logic_vector(1 downto 0) := (others => '0');

    -- Signaux de Synchronisation (DROIT - Y)
    signal r_A_sync_right : std_logic_vector(1 downto 0) := (others => '0');
    signal r_B_sync_right : std_logic_vector(1 downto 0) := (others => '0');
    
begin
    
   
    process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            r_A_sync_left <= (others => '0');
            r_B_sync_left <= (others => '0');
            r_A_sync_right <= (others => '0');
            r_B_sync_right <= (others => '0');
        elsif rising_edge(i_clk) then
            -- GAUCHE (X)
            r_A_sync_left <= r_A_sync_left(0) & i_left_ch_a;
            r_B_sync_left <= r_B_sync_left(0) & i_left_ch_b;
            -- DROIT (Y)
            r_A_sync_right <= r_A_sync_right(0) & i_right_ch_a;
            r_B_sync_right <= r_B_sync_right(0) & i_right_ch_b;
        end if;
    end process;

    
    process(i_clk, i_rst_n)
        variable v_A_rising_L  : boolean;
        variable v_A_falling_L : boolean;
        variable v_B_rising_L  : boolean;
        variable v_B_falling_L : boolean;
        
        variable v_A_rising_R  : boolean;
        variable v_A_falling_R : boolean;
        variable v_B_rising_R  : boolean;
        variable v_B_falling_R : boolean;
    begin
        if i_rst_n = '0' then
            r_coord_x <= (others => '0');
            r_coord_y <= (others => '0');
        elsif rising_edge(i_clk) then
            
            v_A_rising_L  := (r_A_sync_left(0) = '1' and r_A_sync_left(1) = '0');
            v_A_falling_L := (r_A_sync_left(0) = '0' and r_A_sync_left(1) = '1');
            v_B_rising_L  := (r_B_sync_left(0) = '1' and r_B_sync_left(1) = '0');
            v_B_falling_L := (r_B_sync_left(0) = '0' and r_B_sync_left(1) = '1');
            
            v_A_rising_R  := (r_A_sync_right(0) = '1' and r_A_sync_right(1) = '0');
            v_A_falling_R := (r_A_sync_right(0) = '0' and r_A_sync_right(1) = '1');
            v_B_rising_R  := (r_B_sync_right(0) = '1' and r_B_sync_right(1) = '0');
            v_B_falling_R := (r_B_sync_right(0) = '0' and r_B_sync_right(1) = '1');

            
            if (v_A_rising_L and r_B_sync_left(0) = '0') or 
               (v_B_falling_L and r_A_sync_left(0) = '0') then
                if r_coord_x < C_MAX_COORD then
                    r_coord_x <= r_coord_x + 1;
                end if;
            elsif (v_B_rising_L and r_A_sync_left(0) = '0') or 
                  (v_A_falling_L and r_B_sync_left(0) = '0') then 
                if r_coord_x > 0 then
                    r_coord_x <= r_coord_x - 1;
                end if;
            end if;

            
            if (v_A_rising_R and r_B_sync_right(0) = '0') or 
               (v_B_falling_R and r_A_sync_right(0) = '0') then
                if r_coord_y < C_MAX_COORD then
                    r_coord_y <= r_coord_y + 1;
                end if;
            elsif (v_B_rising_R and r_A_sync_right(0) = '0') or 
                  (v_A_falling_R and r_B_sync_right(0) = '0') then 
                if r_coord_y > 0 then
                    r_coord_y <= r_coord_y - 1;
                end if;
            end if;
            
        end if;
    end process;
    
    o_coord_x <= r_coord_x;
    o_coord_y <= r_coord_y;

end architecture rtl;