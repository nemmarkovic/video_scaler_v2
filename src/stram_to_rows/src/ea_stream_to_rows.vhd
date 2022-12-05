----------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.p_axi.all;
    use work.p_handshake.all;

entity stream_to_rows is
   generic(
      G_DWIDTH     : integer := 8;
      G_FIFO_DEPTH : integer := 2048);
   port ( 
		s_axis_aclk	    : in  std_logic;
		s_axis_arst_n	: in  std_logic;
        s_axis_in       : in  axi_s_d1;
        s_axis_out      : out axi_s_d2;

        o_poss          : out natural range 0 to 4095;

        o_pix           : out t_data(data(2 downto 0)(G_DWIDTH -1 downto 0), dextra(2 downto 0));
        i_ack           : in  t_ack);
   end stream_to_rows;

architecture Behavioral of stream_to_rows is

   component  axis_adapter is
      generic(
         G_DWIDTH   : integer := 8);
      port ( 
         s_axis_aclk     : in  std_logic;
         s_axis_arst_n   : in  std_logic;
         s_axis_in       : in  axi_s_d1;
         s_axis_out      : out axi_s_d2;
   
         o_data          : out t_data;
         i_ack           : in  t_ack);
      end component axis_adapter;

   component fifo is
      generic(
         G_FDEPTH    : natural := 2048;
         G_DWIDTH    : natural :=   8);
      port(
         i_clk       : in  std_logic;
         i_rst       : in  std_logic;
   
         i_data      : in  t_data;
         o_ack       : out t_ack;
   
         o_data      : out t_data;
         i_ack       : in  t_ack);
      end component fifo;

   component reg
      generic(
         G_DWIDTH : natural :=    8);
      port(
         i_clk       : in  std_logic;
         i_rst       : in  std_logic;

         i_data      : in  t_data;
         o_ack       : out t_ack;
   
         o_data      : out t_data;
         i_ack       : in  t_ack);
      end component reg;

   signal w_adapt_to_reg  : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
   signal w_reg_to_adapt  : t_ack;

   signal w_reg0_to_dsgn  : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
   signal w_dsgn_to_reg0  : t_ack;

   signal w_dsgn_to_reg1  : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
   signal w_reg1_to_dsgn  : t_ack;

   signal w_dsgn_to_fifo  : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
   signal w_fifo_to_dsgn  : t_ack;

   signal w_reg1_to_out  : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
   signal w_out_to_reg1  : t_ack;

   signal w_fifo_to_out  : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
   signal w_out_to_fifo  : t_ack;

   signal w_to_out       : t_data(data(2-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
   signal w_from_out     : t_ack;

   signal w_oreg_to_out  : t_data(data(2-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));

   type t_dsgn_reg is record
      dsgn_to_reg0    : t_ack;
      reg0_to_dsgn    : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
 
      dsgn_to_fifo    : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
      fifo_to_dsgn    : t_ack;
      dsgn_to_reg1    : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
      reg1_to_dsgn    : t_ack;
      row_cnt        : natural;
   end record t_dsgn_reg;  

   constant t_dsgn_reg_rst : t_dsgn_reg := (
      reg0_to_dsgn => (data => (others => (others =>'0')), handsh => '0', dextra => (others => '0')),
      dsgn_to_reg0 => (ack  => '0'            , full   => '0'),

      dsgn_to_fifo => (data => (others => (others =>'0')), handsh => '0', dextra => (others => '0')),
      fifo_to_dsgn => (ack  => '0'            , full   => '0'),
      dsgn_to_reg1 => (data => (others => (others =>'0')), handsh => '0', dextra => (others => '0')),
      reg1_to_dsgn => (ack  => '0'            , full   => '0'),
      row_cnt     => 0      
      );

   signal R_dsgn, R_dsgn_in : t_dsgn_reg;

   type t_out_reg is record
      dsgn_to_out     : t_data(data(2-1 downto 0)(G_DWIDTH -1 downto 0), dextra (3-1 downto 0));
      out_to_dsgn     : t_ack;
 
      out_to_fifo     : t_ack;
      fifo_to_out     : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
      out_to_reg1     : t_ack;
      reg1_to_out     : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(3-1 downto 0));
   end record t_out_reg;  

   constant t_out_reg_rst : t_out_reg := (
      dsgn_to_out  => (data => (others => (others =>'0')), handsh => '0', dextra => (others => '0')),
      out_to_dsgn  => (ack  => '0'            , full   => '0'),

      fifo_to_out  => (data => (others => (others =>'0')), handsh => '0', dextra => (others => '0')),
      out_to_fifo  => (ack  => '0'            , full   => '0'),
      reg1_to_out  => (data => (others => (others =>'0')), handsh => '0', dextra => (others => '0')),
      out_to_reg1  => (ack  => '0'            , full   => '0'));

   signal R_rd, R_rd_in : t_out_reg;--(data(G_WR_DWIDTH -1 downto 0));

   signal w_reg_to_dsgn  : t_data(data(1-1 downto 0)(G_DWIDTH -1 downto 0), dextra(-1 downto 0));
   signal w_dsgn_to_reg  : t_ack;

begin

-- axi to design adapter
axis_adapter_i : axis_adapter
   generic map(
      G_DWIDTH  => G_DWIDTH)
   port map( 
      s_axis_aclk     => s_axis_aclk,
      s_axis_arst_n   => s_axis_arst_n,
      s_axis_in       => s_axis_in,
      s_axis_out      => s_axis_out,
   
      o_data          => w_adapt_to_reg,
      i_ack           => w_reg_to_adapt);


-- register data from adapter
str2row_reg_inst_0 : reg
   generic map(
      G_DWIDTH   => G_DWIDTH +3)
   port map(
      i_clk      => s_axis_aclk,
      i_rst      => not(s_axis_arst_n),

      i_data     => w_adapt_to_reg,
      o_ack      => w_reg_to_adapt,

      o_data     => w_reg0_to_dsgn,
      i_ack      => w_dsgn_to_reg0);


reg_to_dsgn : process(s_axis_aclk)
   begin
      if rising_edge(s_axis_aclk) then
         if ( not(s_axis_arst_n) = '1') then
             R_dsgn <= t_dsgn_reg_rst;
         else
             R_dsgn <= R_dsgn_in;
         end if;
      end if;
   end process;

-- Function comb process
fnc: process(all)
      variable S : t_dsgn_reg;
   begin
      S := R_dsgn;

      if w_reg0_to_dsgn.dextra(3-1) = '1' then
         S.row_cnt := 0;
      end if;

      if w_reg0_to_dsgn.handsh /= R_dsgn.dsgn_to_reg0.ack then
         if R_dsgn.dsgn_to_reg0.full = '0' then
            S.dsgn_to_reg0.ack := w_reg0_to_dsgn.handsh;
            S.dsgn_to_reg0.full:= '1';
            S.reg0_to_dsgn.data:= w_reg0_to_dsgn.data;

            if w_reg0_to_dsgn.dextra(G_DWIDTH-2) = '1' then
               S.row_cnt := R_dsgn.row_cnt +1;
            end if;

            if w_reg0_to_dsgn.dextra(3-1) = '1' then
               S.row_cnt := 0;
            end if;
         end if;
      end if;


      if S.dsgn_to_reg0.full = '1' then
         if R_dsgn.row_cnt = 0 then
            if ((w_fifo_to_dsgn.ack = R_dsgn.dsgn_to_fifo.handsh) and (w_fifo_to_dsgn.full = '0')) then
               S.dsgn_to_fifo.handsh := not R_dsgn.dsgn_to_fifo.handsh;
               S.dsgn_to_fifo.data   := S.reg0_to_dsgn.data;
               S.dsgn_to_fifo.dextra := S.reg0_to_dsgn.dextra;
               S.dsgn_to_reg0.full   := '0';
            end if;
         else
            if ((w_fifo_to_dsgn.ack = R_dsgn.dsgn_to_fifo.handsh) and (w_fifo_to_dsgn.full = '0') and (w_reg1_to_dsgn.ack = R_dsgn.dsgn_to_reg1.handsh) and (w_reg1_to_dsgn.full = '0')) then
               S.dsgn_to_fifo.handsh := not R_dsgn.dsgn_to_fifo.handsh;
               S.dsgn_to_fifo.data   := S.reg0_to_dsgn.data;

               S.dsgn_to_reg1.handsh := not R_dsgn.dsgn_to_reg1.handsh;
               S.dsgn_to_reg1.data   := S.reg0_to_dsgn.data;
               S.dsgn_to_reg1.dextra := S.reg0_to_dsgn.dextra;

               S.dsgn_to_reg0.full   := '0';
            end if;
         end if;
      end if;

      R_dsgn_in <= S;
   end process;


w_dsgn_to_reg0 <= R_dsgn_in.dsgn_to_reg0;
w_dsgn_to_reg1 <= R_dsgn.dsgn_to_reg1;
w_dsgn_to_fifo <= R_dsgn.dsgn_to_fifo;

str2row_reg_inst_1 : reg
   generic map(
      G_DWIDTH   => G_DWIDTH +3)
   port map(
      i_clk      => s_axis_aclk,
      i_rst      => not(s_axis_arst_n),

      i_data     => w_dsgn_to_reg1,
      o_ack      => w_reg1_to_dsgn,

      o_data     => w_reg1_to_out,
      i_ack      => w_out_to_reg1);


str2row_fifo_inst : fifo
   generic map(
      G_FDEPTH   => 1024,
      G_DWIDTH   => G_DWIDTH)
   port map(
      i_clk      => s_axis_aclk,
      i_rst      => not(s_axis_arst_n),

      i_data     => w_dsgn_to_fifo,
      o_ack      => w_fifo_to_dsgn,

      o_data     =>  w_fifo_to_out,
      i_ack      =>  w_out_to_fifo);


o_poss <= R_dsgn.row_cnt;


rd_out_process : process(s_axis_aclk)
   begin
      if rising_edge(s_axis_aclk) then
         if (not s_axis_arst_n = '1') then
            R_rd <= t_out_reg_rst;
         else
            R_rd <= R_rd_in;
         end if;
      end if;
   end process;

-- Function comb process
fnc_rdout: process(all)
   variable S : t_out_reg;
   begin
      S := R_rd;

--      if R.active = '1' then
         if (w_fifo_to_out.handsh /= R_rd.fifo_to_out.handsh) and (w_reg1_to_out.handsh /= R_rd.reg1_to_out.handsh) then
            if w_from_out.full = '0' then
              S.out_to_fifo.ack  := w_fifo_to_out.handsh;
              S.out_to_fifo.full := '1';
              S.out_to_reg1.ack  := w_reg1_to_out.handsh;
              S.out_to_reg1.full := '1';
              S.reg1_to_out.data := w_reg1_to_out.data;
              S.fifo_to_out.data := w_fifo_to_out.data;
            end if;
         end if;

         if ((S.out_to_reg1.full) and (S.out_to_fifo.full)) = '1' then
            if ((w_from_out.ack = R_rd.dsgn_to_out.handsh) and (w_from_out.full = '0')) then
               S.dsgn_to_out.handsh := not R_rd.dsgn_to_out.handsh;
               S.dsgn_to_out.data   := S.fifo_to_out.data & S.reg1_to_out.data(7 downto 0);
               S.out_to_reg1.full   := '0';
               S.out_to_fifo.full   := '0';
            end if;
         end if;
--      end if;
 
      R_rd_in <= S;
   end process;

   w_out_to_reg1   <= R_rd.out_to_reg1;
   w_out_to_fifo   <= R_rd.out_to_fifo;

   w_to_out        <= R_rd.dsgn_to_out;


reg_out_inst_1 : reg
   generic map(
      G_DWIDTH   => 2* G_DWIDTH +3)
   port map(
      i_clk      => s_axis_aclk,
      i_rst      => not(s_axis_arst_n),

      i_data     => w_to_out,
      o_ack      => w_from_out,

      o_data     => w_oreg_to_out,
      i_ack      => i_ack);

o_pix <= w_oreg_to_out;

end Behavioral;
