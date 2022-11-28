library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use work.p_handshake.all;

entity tb_fifo is
   generic(
      G_FDEPTH : natural := 1024;
      G_DWIDTH : natural :=    8);
   end tb_fifo;

architecture Behavioral of tb_fifo is

component fifo
   generic(
      G_FDEPTH : natural := 1024;
      G_DWIDTH : natural :=    8);
   port(
      i_clk       : in  std_logic;
      i_rst       : in  std_logic;

      i_data      : in  t_data; --(data(G_DWIDTH -1 downto 0));
      o_ack       : out t_ack;

      o_data      : out t_data; --(data(G_DWIDTH -1 downto 0));
      i_ack       : in  t_ack);
   end component fifo;

   signal i_clk       : std_logic;
   signal i_rst       : std_logic;

   signal i_wr_2_reg : t_data;--(data(G_DWIDTH -1 downto 0));
   signal o_reg_2_wr : t_ack;

   signal o_reg_2_rd : t_data;--(data(G_DWIDTH -1 downto 0));
   signal i_rd_2_reg : t_ack;

   constant clk_period : time := 10 ns;

-- helpers
   signal R_wr, R_wr_in : t_data;--(data(G_WR_DWIDTH -1 downto 0));
   signal R_rd, R_rd_in : t_ack;--(data(G_WR_DWIDTH -1 downto 0));


   signal clk_cnt : natural;

begin

-- clk gen process
clk_process: process
begin
   wait for clk_period/2;
      i_clk <= '0';
   wait for clk_period/2;
      i_clk <= '1';
end process;

-- reset process
rst_process: process(i_clk)
   variable cyc_cnt : natural := 0;
begin
   if rising_edge(i_clk) then
      if cyc_cnt >= 10 then
         i_rst <= '0';
      else
         cyc_cnt := cyc_cnt +1;
         i_rst   <= '1';
      end if;
   end if;
end process;

-----------------------------------
-- Dev under test
-----------------------------------
dut_fifo : fifo
   generic map(
      G_FDEPTH    => G_FDEPTH,
      G_DWIDTH    => G_DWIDTH)
   port map(
      i_clk       => i_clk,
      i_rst       => i_rst,

      i_data     => i_wr_2_reg,
      o_ack      => o_reg_2_wr,

      o_data     => o_reg_2_rd,
      i_ack      => i_rd_2_reg);


-----------------------------------
-- Write to fifo
-----------------------------------
wr_reg_process: process(i_clk)
begin
   if rising_edge(i_clk) then
      if i_rst = '1' then
         R_wr.handsh <= '0';
         R_wr.data   <= (others => '0');
      else
         R_wr <= R_wr_in;
      end if;
   end if;
end process;

wr_comb_process: process(all)--(R_wr, o_reg_2_wr, data)
   variable S : t_data;
begin
      if i_rst = '1' then
         R_wr_in.handsh <= '0';
         R_wr_in.data   <= (others => '0');
      else
   S := R_wr;

   if o_reg_2_wr.full = '0' and o_reg_2_wr.ack = R_wr.handsh then
      S.handsh := not R_wr.handsh;
      S.data   := std_logic_vector(unsigned(R_wr.data) +1);
   end if;

   R_wr_in <= S;
   end if;
end process;

i_wr_2_reg.data   <= R_wr.data;
i_wr_2_reg.handsh <= R_wr.handsh;

-----------------------------------
-- Read from fifo
-----------------------------------
rd_reg_process: process(i_clk)
begin
   if rising_edge(i_clk) then
      if i_rst = '1' then
         R_rd.ack <= '0';
         R_rd.full <= '0';
         clk_cnt  <= 0;
      else
         R_rd <= R_rd_in;
         clk_cnt <= (clk_cnt +1) mod 10; 
      end if;
   end if;
end process;

rd_comb_process: process(all)--(R_rd, o_reg_2_rd)
   variable S : t_ack;
begin
   if i_rst = '1' then
      R_rd_in.ack  <= '0';
      R_rd_in.full <= '0';
   else
      S := R_rd;
      if o_reg_2_rd.handsh /= R_rd.ack then
         if clk_cnt = 0 then
         S.ack := o_reg_2_rd.handsh;
         end if;
      end if;
   
      R_rd_in <= S;
   end if;

end process;

i_rd_2_reg.ack   <=  R_rd_in.ack;
i_rd_2_reg.full   <= R_rd_in.full;


end Behavioral;
