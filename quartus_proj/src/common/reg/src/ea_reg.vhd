----------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

    use work.p_handshake.all;

entity ea_reg is
   generic(
      G_DNUM      : natural := 2;
      G_DWIDTH    : natural := 8;
      G_DEXTRA    : natural := C_DEXTRA_MAX);
   port(
      i_clk       : in  std_logic;
      i_rst       : in  std_logic;

      i_data      : in  t_data;
      o_ack       : out t_ack;

      o_data      : out t_data;
      i_ack       : in  t_ack);
   end ea_reg;

architecture Behavioral of ea_reg is

   constant C_DWIDTH : natural := G_DNUM*G_DWIDTH + G_DEXTRA;

   type t_reg is record
      in_data       : std_logic_vector(C_DWIDTH -1 downto 0);
      in_data_ack   : t_ack;
      out_data      : t_data;
      active        : std_logic;
   end record t_reg;  

   constant t_reg_rst : t_reg := (
      in_data       => (others =>'0'),
      in_data_ack   => t_ack_rst,
      active        => '0',
      out_data      => t_data_rst);

   signal R, R_in   : t_reg;

   alias a_eof   : std_logic is i_data.dextra(1);
   alias a_last  : std_logic is i_data.dextra(0);

begin

-- Register process
reg : process(i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_rst = '1') then
             R <= t_reg_rst;
         else
             R <= R_in;
             R.active <= '1';
         end if;
      end if;
   end process;

-- Function comb process
fnc: process(all)
      variable S : t_reg;
   begin
      S := R;

      if R.active = '1' then
         if i_data.handsh /= R.in_data_ack.ack then
            if R.in_data_ack.full = '0' then
              S.in_data_ack.ack := i_data.handsh;
              S.in_data_ack.full:= '1';
              S.in_data         := i_data.dextra & i_data.data(C_DWIDTH - G_DEXTRA -1 downto 0);
            end if;
         end if;

         if S.in_data_ack.full = '1' then
            if ((i_ack.ack = R.out_data.handsh) and (i_ack.full = '0')) then
               S.out_data.handsh := not R.out_data.handsh;
               S.out_data.data(C_DWIDTH - G_DEXTRA -1 downto 0)   := S.in_data(C_DWIDTH - G_DEXTRA -1 downto 0);
               S.out_data.dextra := S.in_data(C_DWIDTH -1 downto C_DWIDTH - G_DEXTRA);
               S.in_data_ack.full:= '0';
            end if;
         end if;
      end if;
 
      R_in <= S;
   end process;

--------------------------------------------------------------------------
-- Outputs assignment
--------------------------------------------------------------------------
   o_ack    <= R_in.in_data_ack;
   o_data   <= R.out_data;


end Behavioral;
