----------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

    use work.p_axi.all;
    use work.p_handshake.all;

entity ea_axis_adapter is
   generic(
      G_DWIDTH   : integer := 8);
   port ( 
		s_axis_aclk	    : in  std_logic;
		s_axis_arst_n	: in  std_logic;
        s_axis_in       : in  axi_s_d1;
        s_axis_out      : out axi_s_d2;

        o_data          : out t_data;
        i_ack           : in  t_ack);
   end ea_axis_adapter;

architecture Behavioral of ea_axis_adapter is

component ea_reg
   generic(
      G_DNUM      : natural;
      G_DWIDTH    : natural;
      G_DEXTRA    : natural;
		G_USE_EXTR  : natural;
		G_USE_POSS  : natural);
   port(
      i_clk       : in  std_logic;
      i_rst       : in  std_logic;

      i_data      : in  t_data;
      o_ack       : out t_ack;

      o_data      : out t_data;
      i_ack       : in  t_ack);
   end component ea_reg;

   constant C_DEXTRA : natural := C_DEXTRA_MAX;
   constant C_DNUM   : natural := 1;

   type t_reg is record
      reg_2_wr_ack  : std_logic;
      wr_data       : std_logic_vector(G_DWIDTH +C_DEXTRA -1 downto 0);
      rd_data       : t_data;
      full          : std_logic;
      reg_2_rd_ack  : std_logic;
   end record t_reg;  

   constant t_reg_rst : t_reg := (
      reg_2_wr_ack => '0',
      wr_data       => (others => '0'),
      rd_data       => t_data_rst,
      full          => '0',
      reg_2_rd_ack  => '0');

   signal R, R_in    : t_reg;
   signal i_wr_2_reg : t_data;
   signal o_reg_2_wr : t_ack;
begin

   process(s_axis_aclk)
   begin
      if rising_edge(s_axis_aclk) then
         if s_axis_arst_n = '0' then
            R <= t_reg_rst;
         else
            R <= R_in;
         end if;
      end if;
   end process;

   process(all)
      variable S : t_reg;
   begin
      S := R;
   
      if ((s_axis_in.tvalid = '1') and (R.full = '0')) then
         S.wr_data := s_axis_in.tuser & s_axis_in.tlast & s_axis_in.tdata;
         S.full    := '1';
      end if;

      if S.full = '1' and o_reg_2_wr.ack = R.rd_data.handsh and o_reg_2_wr.full = '0' then
         S.rd_data.data(G_DWIDTH -1 downto 0) := S.wr_data(G_DWIDTH -1 downto 0);
         S.rd_data.dextra                     := S.wr_data(C_DEXTRA + G_DWIDTH -1 downto G_DWIDTH);
         S.full                               := '0';
         S.rd_data.handsh                     := not R.rd_data.handsh;
      end if;
   
      R_in <= S;
   end process;

   s_axis_out.tready                      <= not(R_in.full);
   i_wr_2_reg.data(i_wr_2_reg.data'high downto G_DWIDTH)  <= (others => '0');
   i_wr_2_reg.data(G_DWIDTH -1 downto 0)  <= R.rd_data.data(G_DWIDTH -1 downto 0);
   i_wr_2_reg.dextra                      <= R.rd_data.dextra;
   i_wr_2_reg.handsh                      <= R.rd_data.handsh;

dut_reg : ea_reg
   generic map(
      G_DNUM      => 1,
      G_DWIDTH    => G_DWIDTH,
      G_DEXTRA    => C_DEXTRA_MAX,
		G_USE_EXTR  => 1,
		G_USE_POSS  => 0)
   port map(
      i_clk       => s_axis_aclk,
      i_rst       => not s_axis_arst_n,

      i_data     => i_wr_2_reg,
      o_ack      => o_reg_2_wr,

      o_data     => o_data,
      i_ack      => i_ack);


end Behavioral;
