----------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

    use work.p_fifo.all;


entity fifo is
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
   end fifo;

architecture Behavioral of fifo is
   constant T_BYTE_WIDTH : natural := 8;

   component tdp_ram
   generic (
      DATA_WIDTH : natural := 32;
      ADDR_WIDTH : natural := 10);
   port(
      clk_a  : in std_logic;
      clk_b  : in std_logic;
      addr_a : in natural range 0 to 2**ADDR_WIDTH - 1;
      addr_b : in natural range 0 to 2**ADDR_WIDTH - 1;
      data_a : in std_logic_vector((DATA_WIDTH-1) downto 0);
      data_b : in std_logic_vector((DATA_WIDTH-1) downto 0);
      we_a   : in std_logic := '1';
      we_b   : in std_logic := '1';
      q_a    : out std_logic_vector((DATA_WIDTH -1) downto 0);
      q_b    : out std_logic_vector((DATA_WIDTH -1) downto 0));
   end component;

   type t_reg is record
      wr_pointer    : natural;
      rd_pointer    : natural;
      pointer_diff  : natural;
      fifo_2_wr_ack : std_logic;
      wr_data       : std_logic_vector(G_WR_DWIDTH -1 downto 0);
      wr_en         : std_logic;


      full          : std_logic;
      empty         : std_logic;

      fifo_2_rd_ack : std_logic;

      rd_data       : std_logic_vector(G_RD_DWIDTH -1 downto 0);
   end record t_reg;  

   constant t_reg_rst : t_reg := (
      wr_pointer    =>  0,
      rd_pointer    =>  0,
      pointer_diff  =>  0,

      fifo_2_wr_ack => '0',
      wr_data       => (others => '0'),
      wr_en         => '0',

      full          => '0',
      empty         => '0',

      fifo_2_rd_ack => '0',
      rd_data       => (others => '0'));

   signal w_rd_data : std_logic_vector(G_WR_DWIDTH -1 downto 0);
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

--      type t_heler_sig is record
--         wr_data    : std_logic_vector(7 downto 0);
--      end record t_heler_sig; 
--      variable V : t_heler_sig;

      variable S : t_reg;
   begin
      S := R;

      if i_wr_2_fifo.wr_req /= R.fifo_2_wr_ack then
         if R.full = '0' then
           S.fifo_2_wr_ack := i_wr_2_fifo.wr_req;
           S.wr_data       := i_wr_2_fifo.data;
           S.wr_en         := '1';
         end if;
         S.pointer_diff  := R.pointer_diff +1;
      end if;

      if R.wr_en = '1' then
         if R.wr_pointer >= G_FDEPTH -1 then
            S.wr_pointer := 0;
         else
            S.wr_pointer   := R.wr_pointer +1; 
         end if;
      end if;

      if R.empty = '0' then
         if i_rd_2_fifo.rd_req /= R.fifo_2_rd_ack then
            S.fifo_2_rd_ack := i_rd_2_fifo.rd_req;
            if  S.wr_pointer /= R.wr_pointer then
               S.pointer_diff := R.pointer_diff;
            else
               S.pointer_diff := R.pointer_diff -1;
            end if;

            if R.rd_pointer >= G_FDEPTH -1 then
               S.rd_pointer := 0;
            else
               S.rd_pointer := R.rd_pointer +1;
            end if;

            S.rd_data := w_rd_data;
         end if;
      end if;


      if R.pointer_diff = 0 then
         S.full  := '0';
         S.empty := '1';
      elsif S.pointer_diff >= G_FDEPTH -1 then
         S.full  := '1';
         S.empty := '0';
      else
         S.full  := '0';
         S.empty := '0';
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


--------------------------------------------------------------------------
-- Memmory read/write proccess
--------------------------------------------------------------------------
tdp_ram_inst: tdp_ram
   generic map(
      DATA_WIDTH => G_WR_DWIDTH,
      ADDR_WIDTH => 10)--ceil(log2(G_FDEPTH)))
   port map(
      clk_a  => i_clk,
      clk_b  => i_clk,
      addr_a => R.wr_pointer,
      addr_b => R_in.rd_pointer,
      data_a => R.wr_data,
      data_b => (others => '0'),
      we_a   => R.wr_en,
      we_b   => '0',
      q_a    => open,
      q_b    => w_rd_data); --o_fifo_2_rd.data);


end Behavioral;
