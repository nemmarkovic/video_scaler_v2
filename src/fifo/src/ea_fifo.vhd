----------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

    use work.p_handshake.all;


entity fifo is
   generic(
      G_FDEPTH    : natural := 2048;
      G_DWIDTH    : natural :=   11);
   port(
      i_clk       : in  std_logic;
      i_rst       : in  std_logic;

      i_data      : in  t_data(data(G_DWIDTH -1 downto 0));
      o_ack       : out t_ack;

      o_data      : out t_data(data(G_DWIDTH -1 downto 0));
      i_ack       : in  t_ack);
   end fifo;

architecture Behavioral of fifo is
   constant T_BYTE_WIDTH : natural := 8;

   component tdp_ram
   generic (
      G_DWIDTH : natural := 32;
      G_AWIDTH : natural := 10);
   port(
      clk_a  : in std_logic;
      clk_b  : in std_logic;
      addr_a : in natural range 0 to 2**G_AWIDTH - 1;
      addr_b : in natural range 0 to 2**G_AWIDTH - 1;
      data_a : in std_logic_vector((G_DWIDTH-1) downto 0);
      data_b : in std_logic_vector((G_DWIDTH-1) downto 0);
      we_a   : in std_logic := '1';
      we_b   : in std_logic := '1';
      q_a    : out std_logic_vector((G_DWIDTH -1) downto 0);
      q_b    : out std_logic_vector((G_DWIDTH -1) downto 0));
   end component;

   type t_reg is record
      in_data       : std_logic_vector(G_DWIDTH -1 downto 0);
      in_data_ack   : t_ack;
      out_data      : t_data(data(G_DWIDTH -1 downto 0));

      wr_pointer    : natural;
      rd_pointer    : natural;
      pointer_diff  : natural;

      wr_en         : std_logic;
      empty         : std_logic;
   end record t_reg;  

   constant t_reg_rst : t_reg := (
      in_data       => (others => '0'),
      in_data_ack   => (full => '0', ack => '0'),
      out_data      => (data => (others => '0'), handsh => '0'),
      
      wr_pointer    =>  0,
      rd_pointer    =>  0,
      pointer_diff  =>  0,

      wr_en         => '0',
      empty         => '1');

   signal R, R_in   : t_reg;
   signal w_rd_data : std_logic_vector(G_DWIDTH -1 downto 0);

begin

-- Register process
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

-- Function comb process
fnc: process(all)
      variable S : t_reg;
   begin
      S := R;

      if R.wr_en = '1' then
         if R.wr_pointer >= G_FDEPTH -1 then
            S.wr_pointer := 0;
         else
            S.wr_pointer   := R.wr_pointer +1; 
         end if;
      end if;

      S.wr_en         := '0';
      if i_data.handsh /= R.in_data_ack.ack then
         if R.in_data_ack.full = '0' then
           S.in_data_ack.ack := i_data.handsh;
           S.wr_en           := '1';
           S.in_data         := i_data.data;
         end if;
         S.pointer_diff  := R.pointer_diff +1;
      end if;

      if R.empty = '0' then
         if ((i_ack.ack = R.out_data.handsh) and (i_ack.full = '0')) then
            S.out_data.handsh := not R.out_data.handsh;
            S.out_data.data   := w_rd_data;
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
         end if;
      end if;

      if R.pointer_diff = 0 then
         S.in_data_ack.full  := '0';
         S.empty             := '1';
      elsif S.pointer_diff >= G_FDEPTH -1 then
         S.in_data_ack.full  := '1';
         S.empty             := '0';
      else
         S.in_data_ack.full  := '0';
         S.empty             := '0';
      end if;

      R_in <= S;
   end process;

----------------------------------------------
-- Outputs assignment
----------------------------------------------
   o_ack    <= R_in.in_data_ack;
   o_data   <= R.out_data;


----------------------------------------------
-- Memmory read/write proccess
----------------------------------------------
tdp_ram_inst: tdp_ram
   generic map(
      G_DWIDTH => G_DWIDTH,
      G_AWIDTH => 10)--ceil(log2(G_FDEPTH)))
   port map(
      clk_a  => i_clk,
      clk_b  => i_clk,
      addr_a => R.wr_pointer,
      addr_b => R_in.rd_pointer,
      data_a => R.in_data,
      data_b => (others => '0'),
      we_a   => R.wr_en,
      we_b   => '0',
      q_a    => open,
      q_b    => w_rd_data); --o_fifo_2_rd.data);


end Behavioral;
