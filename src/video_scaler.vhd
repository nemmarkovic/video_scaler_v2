----------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

    use work.p_axi.all;
    use work.p_handshake.all;

library common_lib;
    use common_lib.p_common.all;

entity video_scaler is
   generic(
      G_DWIDTH     : integer := 8;
      G_FIFO_DEPTH : integer := 2048;
      G_TYPE          : string                := "V"; --"V", "H"
      G_IN_SIZE       : integer               :=  446;
      G_OUT_SIZE      : integer               := 2048;
      G_PHASE_NUM     : integer range 2 to C_MAX_PHASE_NUM := 4);
    port ( 
		s_axis_aclk	    : in  std_logic;
		s_axis_arst_n	: in  std_logic;
        s_axis_in       : in  axi_s_d1;
        s_axis_out      : out axi_s_d2;
        
      o_bank_sel : out std_logic_vector(11 downto 0);
      o_pix      : out t_out_pix_array
    );
end video_scaler;

architecture Behavioral of video_scaler is

component bilinear_flt is
   generic(
      G_TYPE          : string                := "V"; --"V", "H"
      G_IN_SIZE       : integer               :=  446;
      G_OUT_SIZE      : integer               := 2048;
      G_PHASE_NUM     : integer range 2 to C_MAX_PHASE_NUM := 4;
      G_DWIDTH        : integer range 1 to 64 :=    8);
   port ( 
      -- input clk
      i_clk     : in  std_logic;
      -- input reset
      i_rst     : in  std_logic;
      -- ready to filter new data pair
      o_ack     : out  t_ack;
      i_poss    : in   std_logic_vector(11-1 downto 0);
      -- input pixel data
      -- pix0
      -- pix1
      -- last  : std_logic; 
      -- eof   : std_logic;
      i_pix      : in  t_data(data(2*G_DWIDTH +3 -1 downto 0)); --t_in_pix;
      -- next module ready to accept filter outputs
      i_ack     : in  t_ack;
      o_bank_sel : out std_logic_vector(11 downto 0);
      -- output pixel data
      -- data = pix0[G_MANTISA_WIDTH -1 : -G_PRESISION], 
      -- last  : std_logic; 
      -- eof   : std_logic;
      o_pix      : out t_out_pix_array);
   end component;

component stream_to_rows is
   generic(
      G_DWIDTH     : integer := 8;
      G_FIFO_DEPTH : integer := 2048);
   port ( 
		s_axis_aclk	    : in  std_logic;
		s_axis_arst_n	: in  std_logic;
        s_axis_in       : in  axi_s_d1;
        s_axis_out      : out axi_s_d2;

        o_poss          : out std_logic_vector(11-1 downto 0);

        o_pix           : out t_data(data(2 downto 0)(G_DWIDTH -1 downto 0), dextra(2 downto 0));
        i_ack           : in  t_ack);
   end component stream_to_rows;


   signal w_poss        : std_logic_vector(11-1 downto 0);

   signal w_pix         : t_data(data(2 downto 0)(G_DWIDTH -1 downto 0), dextra(2 downto 0));
   signal w_ack         : t_ack;

begin


stream_to_rows_i: stream_to_rows
   generic map(
      G_DWIDTH     => 8,
      G_FIFO_DEPTH => 2048)
   port map( 
		s_axis_aclk	    => s_axis_aclk,
		s_axis_arst_n	=> s_axis_arst_n,
        s_axis_in       => s_axis_in,
        s_axis_out      => s_axis_out,

        o_poss          => w_poss,

        o_pix           => w_pix,
        i_ack           => w_ack);

bilinear_flt_i: bilinear_flt
   generic map(
      G_TYPE          => G_TYPE,
      G_IN_SIZE       => G_IN_SIZE,
      G_OUT_SIZE      => G_OUT_SIZE,
      G_PHASE_NUM     => G_PHASE_NUM,
      G_DWIDTH        => G_DWIDTH)
   port map( 
      i_clk           => s_axis_aclk,
      i_rst           => not s_axis_arst_n,
      o_ack           => w_ack,
      i_pix           => w_pix,
      i_poss          => w_poss,
      i_ack           => (ack => '0', full => '0'),
      o_bank_sel      => o_bank_sel,
      o_pix           => o_pix);


end Behavioral;
