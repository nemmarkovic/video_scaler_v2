library IEEE;
    use IEEE.Std_logic_1164.all;
    use IEEE.Numeric_Std.all;

--library common_lib;
--    use common_lib.p_common.all;

    use work.p_axi.all;
    use work.p_handshake.all;

entity tb_stream_to_rows is
   generic(
      G_DWIDTH   : integer := 8;
      G_FIFO_DEPTH : integer := 16);
   end entity tb_stream_to_rows;

architecture bench of tb_stream_to_rows is

component ea_stream_to_rows is
   generic(
      G_DWIDTH     : integer := 8;
      G_FIFO_DEPTH : integer := 2048);
   port ( 
		s_axis_aclk	    : in  std_logic;
		s_axis_arst_n	: in  std_logic;
        s_axis_in       : in  axi_s_d1;
        s_axis_out      : out axi_s_d2;

        o_poss          : out natural range 0 to 4095;

        o_pix           : out t_data;
        i_ack           : in  t_ack);
   end component ea_stream_to_rows;

--component axi4stream_vip_0
--  port (
--    aclk : IN STD_LOGIC;
--    aresetn : IN STD_LOGIC;
--    m_axis_tvalid : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
--    m_axis_tready : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--    m_axis_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
--    m_axis_tlast : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
--    m_axis_tuser : OUT STD_LOGIC_VECTOR(0 DOWNTO 0));
--end component;
--
--  signal m_axis_tvalid : STD_LOGIC_VECTOR(0 DOWNTO 0);
--  signal m_axis_tready : STD_LOGIC_VECTOR(0 DOWNTO 0);
--  signal m_axis_tdata  : STD_LOGIC_VECTOR(7 DOWNTO 0);
--  signal m_axis_tlast  : STD_LOGIC_VECTOR(0 DOWNTO 0);
--  signal m_axis_tuser  : STD_LOGIC_VECTOR(0 DOWNTO 0);

procedure p_send_data(
   i_vector_data      : in std_logic_vector;
   i_cycles_num_delay : in integer;
   i_clk_period       : in time;
   signal o_data      : out std_logic;
   signal o_dv        : out std_logic) is

   variable p_cnt     : natural;
   variable wait_time : time;
begin
   p_cnt     := 0;
   wait_time := (i_cycles_num_delay * i_clk_period);

   for i in 0 to i_vector_data'length -1 loop
        o_dv   <= '0';
        o_data <= i_vector_data(p_cnt);
      wait for wait_time;
        o_dv   <= '1';
        p_cnt := p_cnt +1;
      wait for i_clk_period;
        o_dv   <= '0';
   end loop;
end p_send_data;

  signal s_axis_aclk   : std_logic;
  signal s_axis_arst_n : std_logic;
  signal s_axis_in     : axi_s_d1;--(tdata(G_WR_DWIDTH -1 downto 0));
  signal s_axis_out    : axi_s_d2;
  signal o_poss        : natural; --std_logic_vector(11-1 downto 0);
  signal o_pix         : t_data;
  signal i_ack         : t_ack;
  signal dummy         : std_logic;
  signal s_start       : std_logic;

  signal data0         : std_logic_vector(7 downto 0);
  signal data1         : std_logic_vector(7 downto 0);

  constant clk_period : time := 10 ns;

   type t_reg is record
      s_axis_in     : axi_s_d1;
   end record t_reg;  

   constant t_reg_rst : t_reg := (
      s_axis_in => (tdata => (others => '0'), tlast => '0', tvalid => '0', tuser => '0'));

   signal R, R_in   : t_reg;

begin

--your_instance_name : axi4stream_vip_0
--  PORT MAP (
--    aclk          => s_axis_aclk,
--    aresetn       => s_axis_arst_n,
--    m_axis_tvalid => m_axis_tvalid,
--    m_axis_tready => m_axis_tready,
--    m_axis_tdata  => m_axis_tdata,
--    m_axis_tlast  => m_axis_tlast,
--    m_axis_tuser  => m_axis_tuser);
--
--s_axis_in.tdata  <= m_axis_tdata;
--s_axis_in.tlast  <= m_axis_tlast(0);
--s_axis_in.tvalid <= m_axis_tvalid(0);
--s_axis_in.tuser  <= m_axis_tuser(0);
--
--m_axis_tready(0)    <= s_axis_out.tready;

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
stream_to_rows_i: ea_stream_to_rows
   generic map (
      G_DWIDTH   => G_DWIDTH,
      G_FIFO_DEPTH => G_FIFO_DEPTH)
   port map (
      s_axis_aclk   => s_axis_aclk,
      s_axis_arst_n => s_axis_arst_n,
      s_axis_in     => s_axis_in,
      s_axis_out    => s_axis_out,
      o_poss        => o_poss,
      o_pix         => o_pix,
      i_ack         => i_ack );


stimulus_reg : process(s_axis_aclk)
      variable v_cnt       : unsigned(7 downto 0);
      variable v_cnt_pause : unsigned(7 downto 0);
   begin
      if rising_edge(s_axis_aclk) then
         if s_axis_arst_n = '0' then
            R <= t_reg_rst;
            i_ack.ack <= '0';
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

         if unsigned(S.s_axis_in.tdata) mod 13 = 0 then
            S.s_axis_in.tlast  := '1';
         end if;
      end if;
      R_in <= S;
   end process;

s_axis_in <= R.s_axis_in;


--stimulus: process(s_axis_aclk)
--      variable v_cnt       : unsigned(7 downto 0);
--      variable v_cnt_pause : unsigned(7 downto 0);
--   begin
--      if rising_edge(s_axis_aclk) then
--         if s_axis_arst_n = '0' then
--            s_axis_in.tuser  <= '0';
--            v_cnt            := (others => '0');
--            v_cnt_pause      := (others => '0');
--         else       
--            if v_cnt_pause < to_unsigned(10,8) then
--               v_cnt_pause := v_cnt_pause +1;
--            elsif(s_axis_out.tready = '1' and s_axis_in.tvalid = '1') then          
--
--               v_cnt            := v_cnt+1;
--               if v_cnt = 9 then             
--               elsif v_cnt = 10 then
--                  v_cnt         := (others => '0');
--                  v_cnt_pause   := (others => '0');
--               end if; 
--            end if;
--         end if;
--      end if;
--   end process;
--
--
--start_proc: process
--   begin
--         s_start <= '0';
--      wait for clk_period *20;
--         s_start <= '1';
--      wait for clk_period;
--         s_start <= '0';
--      wait;
--   end process;
--
--sim_proc: process
--   begin
--      i_ready <= '0';
--      wait until s_start = '1';
--      wait for clk_period/2;
--         p_send_data("0111111010101010111010100101111110101010101110101001011111101010101011101010010111111010101010111010100101111110101010101110101001",1, clk_period, i_ready, dummy);
--      wait for clk_period;
--     wait;
--   end process;
--
--process
--begin
--      s_axis_in.tvalid <= '0';
--      wait until s_start = '1';
--      wait for clk_period/2;
--         p_send_data("1100001010101011101010011111000010101010111010100111110000101010101110101001111100001010101011101010011111000010101010111010100111",1, clk_period, s_axis_in.tvalid, dummy);
--      wait for clk_period;
--      wait;
--end process;
--
--
--      s_axis_in.tlast   <= '1' when unsigned(s_axis_in.tdata) = 10 else
--                           '0' when (s_axis_out.tready = '1' and s_axis_in.tvalid = '1') ;
--
--process(s_axis_aclk)
--   variable v_next : std_logic;
--begin
--   if rising_edge(s_axis_aclk) then
--      if s_axis_arst_n = '0' then
--         v_next            := '0';
--         s_axis_in.tdata  <= (others => '0');
--      else
--
--         if(s_axis_out.tready = '1' and s_axis_in.tvalid = '1') then
--            v_next            := '1';
--            if unsigned(s_axis_in.tdata) = 10 then
--               s_axis_in.tdata   <= (others => '0');
--               v_next            := '0';
--            end if;
--         end if;
--         if v_next = '1' then
--            s_axis_in.tdata   <= std_logic_vector(unsigned(s_axis_in.tdata) +1);
--            v_next            := '0';
--         end if;
--      end if;
--   end if;
--end process;


--   data0 <= o_pix.data( 7 downto 0);
--   data1 <= o_pix.data(15 downto 8);

end;
