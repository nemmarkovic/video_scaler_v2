-------------------------------------------------------------------------------------------------------
-- Following are the steps to compute ac and bc in parallel in one DSP48E2 slice, which is used as an
-- arithmetic unit with a 27-bit pre-adder (both inputs and outputs are 27-bits-wide) and a 27x18
-- multiplier
-- 1) Pack 8-bit input a and b in the 27-bit port p of the DSP48E2 multiplier via the pre-adder so that
--    the 2-bit vectors are as far apart as possible. The input a is left-shifted by only 18-bits so that
--    two sign bits a in the 27-bit result from the first term to prevent overflow in the pre-adder
--    when b<0 and a = -128. The shift amount for a being 18, or the width of the DSP48E2 multiplier
--    port B, is coincidental. 
-- 2) The DSP48E2 27x18 multiplier is used to compute the product of packed 27-bit port p and an 8-bit
--    coefficient represented in 18-bit c in two's complement format. Now this 45-bit product is
--    the sum of two 44-bit terms in two's complement format: ac left-shifted by 18-bits, and bc.
--
--   a * c 
--   b * c
-------------------------------------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

--library ieee_proposed;
--    use ieee_proposed.fixed_pkg.all;

entity mul_cell is
   generic(
      G_DWIDTH : natural :=  8;
      G_RWIDTH : natural := 16;
      G_REG_IN : natural range 0 to 1 := 0);
   port ( 
      i_clk  : in  std_logic;
      i_rst  : in  std_logic;
      i_A    : in  std_logic_vector(G_DWIDTH -1 downto 0);
      i_D    : in  std_logic_vector(G_DWIDTH -1 downto 0);
      i_B    : in  std_logic_vector(G_DWIDTH -1 downto 0);
      i_C    : in  std_logic_vector(48 -1 downto 0);
      o_result:out std_logic_vector(48 -1 downto 0));
--      o_mul1 : out std_logic_vector(G_RWIDTH -1 downto 0);
--      o_mul2 : out std_logic_vector(G_RWIDTH -1 downto 0));
end mul_cell;

architecture Behavioral of mul_cell is
   constant c_zeros : unsigned(19 -1 downto 0) := (others => '0');

   signal r_result  : unsigned(48 -1 downto 0);

   -- pack A and D inside P wia pre-adder
   signal l_dsp_post_adder : unsigned(27 -1 downto 0);
   signal l_mac            : unsigned(48 -1 downto 0);

   signal w_A              : unsigned(27 -1  downto 0);
   signal w_D              : unsigned(27 -1 downto 0);
   signal w_B              : unsigned(18 -1 downto 0);
   signal w_C              : unsigned(48 -1 downto 0);

   attribute use_dsp : string;
--   attribute use_dsp of l_p : signal is "yes";
--   attribute use_dsp of w_add    : signal is "no";

begin

reg_in : if G_REG_IN = 1 generate
      signal r_A              : unsigned(G_DWIDTH -1 downto 0);
      signal r_B              : unsigned(G_DWIDTH -1 downto 0);
      signal r_D              : unsigned(G_DWIDTH -1 downto 0);
      signal r_C              : unsigned(48 -1 downto 0);
   begin
   reg_in_proc: process(i_clk)
      begin
         if rising_edge(i_clk) then
            if i_rst = '1' then
               r_A      <= (others => '0');
               r_B      <= (others => '0');
               r_D      <= (others => '0');
               r_C      <= (others => '0');
            else
               r_A      <= unsigned(i_A);
               r_B      <= unsigned(i_B);
               r_D      <= unsigned(i_D);
               r_C      <= unsigned(i_C);
            end if;
         end if;
      end process;
      w_A <= c_zeros & unsigned(r_A);
      w_D <=  unsigned(r_D) & c_zeros;
      w_B <= "0000000000" & unsigned(r_B);
      w_C <= r_C;
   else generate
      w_A <= c_zeros & unsigned(i_A);
      w_D <=  unsigned(i_D) & c_zeros; 
      w_B <= "0000000000" & unsigned(i_B);
      w_C <= unsigned(i_C);
   end generate;

   l_dsp_post_adder      <= w_A + w_D;

dsp_mul_p: process(i_clk)
   begin
      if rising_edge(i_clk) then
         if i_rst = '1' then
            r_result <= (others => '0');
         else
            r_result <= "000" & l_dsp_post_adder * w_B;
         end if;
      end if;   
   end process;

   l_mac   <= r_result + unsigned(w_C);
   o_result <= std_logic_vector(l_mac);
--   o_mul1 <= std_logic_vector(l_mac(15 downto 0));
--   o_mul2 <= std_logic_vector(l_mac(34 downto 19));

end Behavioral;
