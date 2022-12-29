-- Testbench created online at:
--   https://www.doulos.com/knowhow/perl/vhdl-testbench-creation-using-perl/
-- Copyright Doulos Ltd

library IEEE;
    use IEEE.Std_logic_1164.all;
    use IEEE.Numeric_Std.all;

--library common_lib;
--    use common_lib.p_common.all;

    use work.p_axi.all;
    use work.p_handshake.all;

entity video_scaler_tb is
     generic(
        G_DWIDTH        : integer := 8;
        G_FIFO_DEPTH    : integer := 2048;
        G_TYPE          : string                := "V";
        G_IN_SIZE       : integer               :=  5;
        G_OUT_SIZE      : integer               := 11;
        G_PHASE_NUM     : integer range 2 to 8  :=    4);
end;

architecture bench of video_scaler_tb is

  component video_scaler
     generic(
        G_DWIDTH        : integer := 8;
        G_FIFO_DEPTH    : integer := 2048;
        G_TYPE          : string                := "V";
        G_IN_SIZE       : integer               :=  446;
        G_OUT_SIZE      : integer               := 2048;
        G_PHASE_NUM     : integer range 2 to 8  :=    4);
      port ( 
        s_axis_aclk     : in  std_logic;
        s_axis_arst_n	: in  std_logic;
        s_axis_in       : in  axi_s_d1;
        s_axis_out      : out axi_s_d2;
        
        i_ack           : in  t_ack;
        
        s_axis_2_aclk   : in  std_logic;
        s_axis_2_arst_n : in  std_logic;
        s_axis_2_out    : out axi_s_d1;
        s_axis_2_in     : in  axi_s_d2
      );
  end component;

  signal s_axis_aclk: std_logic;
  signal s_axis_arst_n: std_logic;
  signal s_axis_in: axi_s_d1;
  signal s_axis_out: axi_s_d2;
  signal s_axis_2_aclk: std_logic;
  signal s_axis_2_arst_n: std_logic;
  signal s_axis_2_out: axi_s_d1;
  signal s_axis_2_in: axi_s_d2 ;

  constant clk_period : time := 10 ns;

   type t_reg is record
      s_axis_in     : axi_s_d1;
   end record t_reg;  

   constant t_reg_rst : t_reg := (
      s_axis_in => (tdata => (others => '0'), tlast => '0', tvalid => '0', tuser => '0'));

   signal R, R_in   : t_reg;

  signal i_ack         : t_ack;

begin

clk_proc: process
  begin
     s_axis_aclk <= '0';
        wait for clk_period/2; 
     s_axis_aclk <= '1';
        wait for clk_period/2;
  end process;
  
rst_proc: process
  begin
        s_axis_arst_n <= '0';
     wait for clk_period *10; 
     wait until rising_edge(s_axis_aclk);
        s_axis_arst_n <= '1';
     wait;
  end process;


  -- Insert values for generic parameters !!
   uut: video_scaler 
      generic map (      
         G_DWIDTH     =>    8,
         G_FIFO_DEPTH => 2048,
         G_TYPE       => "V", --"V", "H"
         G_IN_SIZE    =>  G_IN_SIZE,
         G_OUT_SIZE   => G_OUT_SIZE,
         G_PHASE_NUM  =>    4)
      port map ( 
         s_axis_aclk     => s_axis_aclk,
         s_axis_arst_n   => s_axis_arst_n,
         s_axis_in       => s_axis_in,
         s_axis_out      => s_axis_out,

         i_ack           => i_ack,

         s_axis_2_aclk   => s_axis_2_aclk,
         s_axis_2_arst_n => s_axis_2_arst_n,
         s_axis_2_out    => s_axis_2_out,
         s_axis_2_in     => s_axis_2_in );

stimulus_reg : process(s_axis_aclk)
      variable v_cnt       : unsigned(7 downto 0);
      variable v_cnt_pause : unsigned(7 downto 0);
   begin
      if rising_edge(s_axis_aclk) then
         if s_axis_arst_n = '0' then
            R <= t_reg_rst;
            i_ack.ack  <= '0';
            i_ack.full <= '0';
         else       
            R <= R_in;
            i_ack.ack <= not i_ack.ack;
         end if;
      end if;
   end process;

stimulus_cmb: process(R, s_axis_aclk, s_axis_arst_n, s_axis_out)
      variable S : t_reg;
   begin
      S := R;

      S.s_axis_in.tvalid := '0';
      if s_axis_out.tready = '1' then
         S.s_axis_in.tdata  := std_logic_vector(unsigned(R.s_axis_in.tdata) +1);
         S.s_axis_in.tvalid := '1';
         S.s_axis_in.tlast  := '0';
         S.s_axis_in.tuser  := '0';

         if unsigned(S.s_axis_in.tdata) mod G_IN_SIZE = 0 then
            S.s_axis_in.tlast  := '1';
         end if;
      end if;
      R_in <= S;
   end process;

s_axis_in <= R.s_axis_in;


end;