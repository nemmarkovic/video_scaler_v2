library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;

library ieee_proposed;
    use ieee_proposed.fixed_pkg.all;

library common_lib;
    use common_lib.p_common.all;

entity filter_cell is
   generic(
      G_DWIDTH        : integer range 1 to 64 :=    8;
      G_PRESISION     : integer range 1 to 64 :=    6);
   port ( 
      i_clk    : in  std_logic;
      i_rst    : in  std_logic;
      i_valid  : in  std_logic;
      i_pix    : in  t_dinfo(data(0 to 1)(G_DWIDTH -1 downto 0));
      i_SFY    : in  sfixed(C_SF_WIDTH -1 downto -G_PRESISION);
      i_colmun : in  std_logic_vector(11 -1 downto 0);
      i_ocolmun: in  std_logic_vector(11 -1 downto 0);
      o_pix    : out t_dinfo(data(0 to 0)(G_DWIDTH -1 downto 0));
      o_valid  : out std_logic);
   end filter_cell;

architecture Behavioral of filter_cell is
    signal r_out_valid : std_logic;
    signal s_opix      : t_dinfo(data(0 to 0)(G_DWIDTH -1 downto 0));
begin

cell_filt_p: process(i_clk)
      variable tap_val          : sfixed(G_DWIDTH +1 downto -G_PRESISION);
      variable tap_val1         : sfixed(G_DWIDTH +1 downto -G_PRESISION);
      variable v_ipix_0         : sfixed(G_DWIDTH  downto -G_PRESISION);
      variable v_ipix_1         : sfixed(G_DWIDTH downto -G_PRESISION);
      variable v_out_pix        : sfixed(G_DWIDTH  downto 0);--RESISION);
   begin
      if rising_edge(i_clk) then
         if i_rst = '1' then
            r_out_valid    <= '0';
            v_out_pix      := (others => '0');
            s_opix.data(0) <= "00000000";--(others => '0');
            s_opix.last    <= '0';
            s_opix.eof     <= '0';
         else
            v_ipix_0 := to_sfixed(to_integer(unsigned(i_pix.data(0))), G_DWIDTH, -G_PRESISION);
            v_ipix_1 := to_sfixed(to_integer(unsigned(i_pix.data(1))), G_DWIDTH, -G_PRESISION);

               tap_val     := resize((to_sfixed(to_integer(unsigned(i_ocolmun)),11, -G_PRESISION)* i_SFY), G_DWIDTH +1, -G_PRESISION);
               tap_val1    := resize((to_sfixed(1 , G_DWIDTH +1, -G_PRESISION))- tap_val,  G_DWIDTH +1, -G_PRESISION);            
               v_out_pix   := resize(resize(v_ipix_0 * tap_val1, G_DWIDTH, -G_PRESISION) +
                                     resize(v_ipix_1 * tap_val , G_DWIDTH, -G_PRESISION), G_DWIDTH, 0);---G_PRESISION);

            if i_valid = '1' then         

               r_out_valid    <= '1';
               s_opix.data(0) <= std_logic_vector(v_out_pix(G_DWIDTH -1 downto 0));
               s_opix.last    <= '0';
               s_opix.eof     <= '0';
            else
               r_out_valid <= '0';
               s_opix.data(0) <= "00000000";--(others => '0');
               s_opix.last    <= i_pix.last;
               s_opix.eof     <= i_pix.eof;
            end if;         
         end if;
      end if;

   end process;

   o_pix    <= s_opix;
   o_valid  <= r_out_valid;

end Behavioral;
