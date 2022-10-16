library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use work.p_fifo.all;

entity tb_reg is
   generic(
      G_FDEPTH    : natural := 1024;
      G_WR_DWIDTH : natural :=    8;
      G_RD_DWIDTH : natural :=    8);
   end tb_reg;

architecture Behavioral of tb_reg is

component reg
   generic(
      G_FDEPTH    : natural := 1024;
      G_WR_DWIDTH : natural :=    8;
      G_RD_DWIDTH : natural :=    8);
   port(
      i_clk       : in  std_logic;
      i_rst       : in  std_logic;

      i_wr_2_fifo : in  t_wr_2_fifo;--(data(G_WR_DWIDTH -1 downto 0));
      o_fifo_2_wr : out t_fifo_2_wr;

      o_fifo_2_rd : out t_fifo_2_rd;--(data(G_RD_DWIDTH -1 downto 0));
      i_rd_2_fifo : in  t_rd_2_fifo);
   end component reg;


   signal i_clk       : std_logic;
   signal i_rst       : std_logic;

   signal i_wr_2_fifo : t_wr_2_fifo;--(data(G_WR_DWIDTH -1 downto 0));
   signal o_fifo_2_wr : t_fifo_2_wr;

   signal o_fifo_2_rd : t_fifo_2_rd;--(data(G_RD_DWIDTH -1 downto 0));
   signal i_rd_2_fifo : t_rd_2_fifo;

   constant clk_period : time := 10 ns;

-- helpers
   signal R_wr, R_wr_in : t_wr_2_fifo;--(data(G_WR_DWIDTH -1 downto 0));
   signal R_rd, R_rd_in : t_rd_2_fifo;--(data(G_WR_DWIDTH -1 downto 0));


   signal clk_cnt : natural;--(data(G_WR_DWIDTH -1 downto 0));

begin

dut_reg : reg
   generic map(
      G_FDEPTH    => G_FDEPTH,
      G_WR_DWIDTH => G_WR_DWIDTH,
      G_RD_DWIDTH => G_RD_DWIDTH)
   port map(
      i_clk       => i_clk,
      i_rst       => i_rst,

      i_wr_2_fifo => i_wr_2_fifo,
      o_fifo_2_wr => o_fifo_2_wr,

      o_fifo_2_rd => o_fifo_2_rd,
      i_rd_2_fifo => i_rd_2_fifo);

clk_process: process
begin
   wait for clk_period/2;
      i_clk <= '0';
   wait for clk_period/2;
      i_clk <= '1';
end process;

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


wr_reg_process: process(i_clk)
begin
   if rising_edge(i_clk) then
      if i_rst = '1' then
         R_wr.wr_req <= '0';
         R_wr.data   <= (others => '0');
      else
         R_wr <= R_wr_in;
      end if;
   end if;
end process;

wr_comb_process: process(all)--(R_wr, o_fifo_2_wr, data)
   variable S : t_wr_2_fifo;
begin

   S := R_wr;

   if o_fifo_2_wr.full = '0' and o_fifo_2_wr.wr_ack = R_wr.wr_req then
      S.wr_req := not R_wr.wr_req;
      S.data   := std_logic_vector(unsigned(R_wr.data) +1);
   end if;

   R_wr_in <= S;

end process;

i_wr_2_fifo.data   <= R_wr.data;
i_wr_2_fifo.wr_req <= R_wr.wr_req;


rd_reg_process: process(i_clk)
begin
   if rising_edge(i_clk) then
      if i_rst = '1' then
         R_rd.rd_req <= '0';
         clk_cnt <= 0;
      else
         R_rd <= R_rd_in;
         clk_cnt <= (clk_cnt +1) mod 10; 
      end if;
   end if;
end process;

rd_comb_process: process(all)--(R_rd, o_fifo_2_rd)
   variable S : t_rd_2_fifo;
begin

   S := R_rd;
   if o_fifo_2_rd.rd_ack = R_rd.rd_req then
  --    if clk_cnt = 0 then
      S.rd_req := not R_rd.rd_req;
  --    end if;
   end if;

   R_rd_in <= S;

end process;

   i_rd_2_fifo.rd_req   <= R_rd.rd_req;

end Behavioral;
