----------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

    use work.p_fifo.all;

entity reg is
   generic(
      G_FDEPTH    : natural := 1024;
      G_WR_DWIDTH : natural :=    8;
      G_RD_DWIDTH : natural :=    8);
   port(
      i_clk       : in  std_logic;
      i_rst       : in  std_logic;

      i_wr_2_fifo : in  t_wr_2_fifo; --(data(G_WR_DWIDTH -1 downto 0));
      o_fifo_2_wr : out t_fifo_2_wr;

      o_fifo_2_rd : out t_fifo_2_rd; --(data(G_RD_DWIDTH -1 downto 0));
      i_rd_2_fifo : in  t_rd_2_fifo);
   end reg;

architecture Behavioral of reg is
   type t_reg is record
      fifo_2_wr_ack : std_logic;
      wr_data       : std_logic_vector(G_WR_DWIDTH -1 downto 0);

      full          : std_logic;

      fifo_2_rd_ack : std_logic;

      rd_data       : std_logic_vector(G_RD_DWIDTH -1 downto 0);
   end record t_reg;  

   constant t_reg_rst : t_reg := (

      fifo_2_wr_ack => '0',
      wr_data       => (others => '0'),

      full          => '0',

      fifo_2_rd_ack => '0',
      rd_data       => (others => '0'));

   signal R, R_in   : t_reg;

begin

------------------------------------------------
-- Register process
------------------------------------------------
reg : process(i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_rst = '1') then
             R <= t_reg_rst;
         else
             R <= R_in;
         end if;
      end if;
   end process;

------------------------------------------------
-- Function comb process
------------------------------------------------
fnc: process(R, i_wr_2_fifo, i_rd_2_fifo)

      variable S : t_reg;
   begin
      S := R;

      if i_wr_2_fifo.wr_req /= R.fifo_2_wr_ack then
         if R.full = '0' then
           S.fifo_2_wr_ack := i_wr_2_fifo.wr_req;
           S.wr_data       := i_wr_2_fifo.data;
           S.full          := '1';
         end if;
      end if;

      if S.full = '1' then
         if i_rd_2_fifo.rd_req /= R.fifo_2_rd_ack then
            S.fifo_2_rd_ack := i_rd_2_fifo.rd_req;

            S.rd_data := S.wr_data;
            S.full := '0';
         end if;
      end if;

      R_in <= S;
   end process;

--------------------------------------------------------------------------
-- Outputs assignment
--------------------------------------------------------------------------
o_fifo_2_rd.data   <= R_in.rd_data;
o_fifo_2_rd.rd_ack <= R_in.fifo_2_rd_ack;

o_fifo_2_wr.full   <= R_in.full;
o_fifo_2_wr.wr_ack <= R_in.fifo_2_wr_ack;

end Behavioral;
