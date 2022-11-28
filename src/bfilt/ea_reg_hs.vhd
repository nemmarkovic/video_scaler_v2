library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;

entity reg_hs is
   generic(
      G_DWIDTH : positive := 8);
   port (
      i_clk   : in  std_logic;
      i_rst   : in  std_logic;
      i_data  : in  std_logic_vector(G_DWIDTH -1 downto 0);
      i_valid : in  std_logic;
      o_ready : out std_logic;
      i_ready : in  std_logic;
      o_valid : out std_logic;
      o_data  : out std_logic_vector(G_DWIDTH -1 downto 0));
   end reg_hs;

architecture Behavioral of reg_hs is
   signal r_reg_data   : std_logic_vector(G_DWIDTH -1 downto 0);
   signal l_in_data    : std_logic_vector(G_DWIDTH -1 downto 0);
   
   signal r_dvalid     : std_logic;
   signal l_dvalid     : std_logic;
   signal r_dready   : std_logic;
   signal l_dready   : std_logic;

begin  

comb_proc: process(all)
   begin
      l_dready    <= '0';
      if (i_ready) = '1' then
         l_dready    <= '1';
      end if;
   end process;

reg_out_proc: process(i_clk)
      variable start : std_logic;
   begin
      if rising_edge(i_clk) then
         if (i_rst) = '1' then

         else
            o_ready    <= l_dready;

            if (i_valid and l_dready) = '1' then
               r_reg_data <= i_data;
               o_valid    <= '1';
            elsif l_dready = '1' then
               o_valid    <= '0';
            end if;
         end if;
      end if;
   end process;

o_data <= r_reg_data;

end Behavioral;
