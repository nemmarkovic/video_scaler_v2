----------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

    use work.p_axi.all;
    use work.p_handshake.all;

entity axis_adapter is
   generic(
      G_DWIDTH   : integer := 8);
   port ( 
		s_axis_aclk	    : in  std_logic;
		s_axis_arst_n	: in  std_logic;
        s_axis_in       : in  axi_s_d1;
        s_axis_out      : out axi_s_d2;

        o_data          : out t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
        i_ack           : in  t_ack);
   end axis_adapter;

architecture Behavioral of axis_adapter is

component reg
   generic(
      G_DNUM      : natural;
      G_DWIDTH    : natural;
      G_DEXTRA    : natural);
   port(
      i_clk       : in  std_logic;
      i_rst       : in  std_logic;

      i_data      : in  t_data;
      o_ack       : out t_ack;

      o_data      : out t_data;
      i_ack       : in  t_ack);
   end component reg;

   constant C_DEXTRA : natural := 3;
   constant C_DNUM   : natural := 1;

   type t_reg is record
      reg_2_wr_ack  : std_logic;
      wr_data       : std_logic_vector(G_DWIDTH +3 -1 downto 0);
      rd_data       : t_data(data(C_DNUM-1 downto 0)(G_DWIDTH-1 downto 0), dextra(C_DEXTRA-1 downto 0));
      full          : std_logic;
      reg_2_rd_ack : std_logic;
   end record t_reg;  

   constant t_reg_rst : t_reg := (
      reg_2_wr_ack => '0',
      wr_data       => (others => '0'),
      rd_data       => (data => (others => (others =>'0')), handsh => '0', dextra => (others => '0')),
      full          => '0',
      reg_2_rd_ack  => '0');

   signal R, R_in    : t_reg;
   signal i_wr_2_reg : t_data(data(C_DNUM-1 downto 0)(G_DWIDTH-1 downto 0), dextra(C_DEXTRA-1 downto 0));
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
      S.wr_data := s_axis_in.tuser & s_axis_in.tlast & s_axis_in.tvalid & s_axis_in.tdata;
      S.full    := '1';
   end if;

   if S.full = '1' and o_reg_2_wr.ack = R.rd_data.handsh and o_reg_2_wr.full = '0' then
      S.rd_data.data(0)    := S.wr_data(G_DWIDTH -1 downto 0);
      S.rd_data.dextra     := S.wr_data(C_DEXTRA + G_DWIDTH -1 downto G_DWIDTH);
      S.full            := '0';
      S.rd_data.handsh  := not R.rd_data.handsh;
   end if;
   
   R_in <= S;
end process;

s_axis_out.tready <= not(R_in.full);
i_wr_2_reg.data   <= R.rd_data.data;
i_wr_2_reg.handsh <= R.rd_data.handsh;

dut_reg : reg
   generic map(
      G_DNUM      => 1,
      G_DWIDTH    => G_DWIDTH,
      G_DEXTRA    => 3)
   port map(
      i_clk       => s_axis_aclk,
      i_rst       => not s_axis_arst_n,

      i_data     => i_wr_2_reg,
      o_ack      => o_reg_2_wr,

      o_data     => o_data,
      i_ack      => i_ack);


end Behavioral;
