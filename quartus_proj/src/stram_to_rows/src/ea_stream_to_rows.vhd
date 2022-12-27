----------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.p_axi.all;
    use work.p_handshake.all;

entity ea_stream_to_rows is
   generic(
      G_DWIDTH     : integer := 8;
      G_FIFO_DEPTH : integer := C_FIFO_DEPTH);
   port ( 
		s_axis_aclk	    : in  std_logic;
		s_axis_arst_n	 : in  std_logic;
      s_axis_in       : in  axi_s_d1;
      s_axis_out      : out axi_s_d2;

      o_pix           : out t_data;
      i_ack           : in  t_ack);
   end ea_stream_to_rows;

architecture Behavioral of ea_stream_to_rows is

component ea_axis_adapter
   generic(
      G_DWIDTH        : integer);
   port ( 
		s_axis_aclk	    : in  std_logic;
		s_axis_arst_n	 : in  std_logic;
      s_axis_in       : in  axi_s_d1;
      s_axis_out      : out axi_s_d2;

      o_data          : out t_data;
      i_ack           : in  t_ack);
   end component ea_axis_adapter;

component ea_fifo
   generic(
      G_FDEPTH    : natural;
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
   end component ea_fifo;

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



   signal w_adapt_to_reg  : t_data;
   signal w_reg_to_adapt  : t_ack;

   signal w_reg0_to_dsgn  : t_data;
   signal w_dsgn_to_reg0  : t_ack;

   signal w_dsgn_to_reg1  : t_data;
   signal w_reg1_to_dsgn  : t_ack;

   signal w_dsgn_to_fifo  : t_data;
   signal w_fifo_to_dsgn  : t_ack;

   signal w_reg1_to_out  : t_data;
   signal w_out_to_reg1  : t_ack;

   signal w_fifo_to_out  : t_data;
   signal w_out_to_fifo  : t_ack;

   signal w_to_out       : t_data;
   signal w_from_out     : t_ack;

   signal w_oreg_to_out  : t_data;

   type t_dsgn_reg is record
      dsgn_to_reg0    : t_ack;
      reg0_to_dsgn    : t_data;
 
      dsgn_to_fifo    : t_data;
      fifo_to_dsgn    : t_ack;
      dsgn_to_reg1    : t_data;
      reg1_to_dsgn    : t_ack;
      row_cnt        : natural;
   end record t_dsgn_reg;  

   constant t_dsgn_reg_rst : t_dsgn_reg := (
      reg0_to_dsgn => t_data_rst,
      dsgn_to_reg0 => t_ack_rst,

      dsgn_to_fifo => t_data_rst,
      fifo_to_dsgn => t_ack_rst,
      dsgn_to_reg1 => t_data_rst,
      reg1_to_dsgn => t_ack_rst,
      row_cnt     => 0);

   signal R_dsgn, R_dsgn_in : t_dsgn_reg;

   type t_out_reg is record
      dsgn_to_out     : t_data;
 
      out_to_fifo     : t_ack;
      reg_fifo_to_out : t_data;
      out_to_reg1     : t_ack;
   end record t_out_reg;  

   constant t_out_reg_rst : t_out_reg := (
      dsgn_to_out  => t_data_rst,

      reg_fifo_to_out => t_data_rst,
      out_to_fifo     => t_ack_rst,
      out_to_reg1     => t_ack_rst);

   signal R_rd, R_rd_in : t_out_reg;--(data(G_WR_DWIDTH -1 downto 0));

   signal w_reg_to_dsgn  : t_data;
   signal w_dsgn_to_reg  : t_ack;

begin

-- axi to design adapter
axis_adapter_i : ea_axis_adapter
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
str2row_reg_inst_0 : ea_reg
   generic map(
      G_DNUM      => 1,
      G_DWIDTH    => G_DWIDTH,
      G_DEXTRA    => C_DEXTRA_MAX,
		G_USE_EXTR  => 1,
		G_USE_POSS  => 0)
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

      if w_reg0_to_dsgn.dextra(1) = '1' then
         S.row_cnt := 0;
      end if;

      if w_reg0_to_dsgn.handsh /= R_dsgn.dsgn_to_reg0.ack then
         if R_dsgn.dsgn_to_reg0.full = '0' then
            S.dsgn_to_reg0.ack := w_reg0_to_dsgn.handsh;
            S.dsgn_to_reg0.full:= '1';
            S.reg0_to_dsgn.data(G_DWIDTH -1 downto 0):= w_reg0_to_dsgn.data(G_DWIDTH -1 downto 0);
            S.reg0_to_dsgn.dextra                    := w_reg0_to_dsgn.dextra;

            if w_reg0_to_dsgn.dextra(0) = '1' then
               S.row_cnt := R_dsgn.row_cnt +1;
            end if;

            if w_reg0_to_dsgn.dextra(1) = '1' then
               S.row_cnt := 0;
            end if;
         end if;
      end if;


      if S.dsgn_to_reg0.full = '1' then
         if R_dsgn.row_cnt = 0 then
            if ((w_fifo_to_dsgn.ack = R_dsgn.dsgn_to_fifo.handsh) and (w_fifo_to_dsgn.full = '0')) then
               S.dsgn_to_fifo.handsh                     := not R_dsgn.dsgn_to_fifo.handsh;
               S.dsgn_to_fifo.data(G_DWIDTH -1 downto 0) := S.reg0_to_dsgn.data(G_DWIDTH -1 downto 0);
               S.dsgn_to_fifo.dextra                     := S.reg0_to_dsgn.dextra;
               S.dsgn_to_reg0.full                       := '0';
            end if;
         else
            if ((w_fifo_to_dsgn.ack = R_dsgn.dsgn_to_fifo.handsh) and (w_fifo_to_dsgn.full = '0') and (w_reg1_to_dsgn.ack = R_dsgn.dsgn_to_reg1.handsh) and (w_reg1_to_dsgn.full = '0')) then
               S.dsgn_to_fifo.handsh                     := not R_dsgn.dsgn_to_fifo.handsh;
               S.dsgn_to_fifo.data(G_DWIDTH -1 downto 0) := S.reg0_to_dsgn.data(G_DWIDTH -1 downto 0);
               S.dsgn_to_fifo.dextra                     := S.reg0_to_dsgn.dextra;

               S.dsgn_to_reg1.handsh                     := not R_dsgn.dsgn_to_reg1.handsh;
               S.dsgn_to_reg1.data(G_DWIDTH -1 downto 0) := S.reg0_to_dsgn.data(G_DWIDTH -1 downto 0);
               S.dsgn_to_reg1.dextra                     := S.reg0_to_dsgn.dextra;
               S.dsgn_to_reg1.possition                  := std_logic_vector(to_unsigned(S.row_cnt, C_POS_WIDTH));

               S.dsgn_to_reg0.full                       := '0';
            end if;
         end if;
      end if;

      R_dsgn_in <= S;
   end process;


w_dsgn_to_reg0 <= R_dsgn_in.dsgn_to_reg0;
w_dsgn_to_reg1 <= R_dsgn.dsgn_to_reg1;
w_dsgn_to_fifo <= R_dsgn.dsgn_to_fifo;

str2row_reg_inst_1 : ea_reg
   generic map(
      G_DNUM      => 1,
      G_DWIDTH    => G_DWIDTH,
      G_DEXTRA    => C_DEXTRA_MAX,
		G_USE_EXTR  => 1,
		G_USE_POSS  => 1)
   port map(
      i_clk      => s_axis_aclk,
      i_rst      => not(s_axis_arst_n),

      i_data     => w_dsgn_to_reg1,
      o_ack      => w_reg1_to_dsgn,

      o_data     => w_reg1_to_out,
      i_ack      => w_out_to_reg1);


str2row_fifo_inst : ea_fifo
   generic map(
      G_FDEPTH    => G_FIFO_DEPTH,
      G_DNUM      => 1,
      G_DWIDTH    => G_DWIDTH,
      G_DEXTRA    => C_DEXTRA_MAX,
		G_USE_EXTR  => 1,
		G_USE_POSS  => 0)
   port map(
      i_clk      => s_axis_aclk,
      i_rst      => not(s_axis_arst_n),

      i_data     => w_dsgn_to_fifo,
      o_ack      => w_fifo_to_dsgn,

      o_data     =>  w_fifo_to_out,
      i_ack      =>  w_out_to_fifo);


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

      if (w_fifo_to_out.handsh /= R_rd.out_to_fifo.ack) and (w_reg1_to_out.handsh /= R_rd.out_to_reg1.ack) then
         if R_rd.out_to_fifo.full = '0' and R_rd.out_to_reg1.full = '0' then
      		S.out_to_fifo.ack  := w_fifo_to_out.handsh;
            S.out_to_reg1.ack  := w_reg1_to_out.handsh;
            S.out_to_fifo.full := '1';
            S.out_to_reg1.full := '1';

            S.reg_fifo_to_out.data(2*G_DWIDTH -1 downto 0) := w_fifo_to_out.data(G_DWIDTH -1 downto 0) & w_reg1_to_out.data(G_DWIDTH -1 downto 0);
				S.reg_fifo_to_out.possition                    := w_reg1_to_out.possition;
            S.reg_fifo_to_out.dextra := w_fifo_to_out.dextra;
				S.reg_fifo_to_out.handsh := not R_rd.reg_fifo_to_out.handsh;
		   end if;
		end if;

		
      if ((S.out_to_reg1.full) and (S.out_to_fifo.full)) = '1' then
         if ((w_from_out.ack = R_rd.dsgn_to_out.handsh) and (w_from_out.full = '0')) then

            S.out_to_fifo.full := '0';
            S.out_to_reg1.full := '0';
			
			   S.dsgn_to_out.handsh                        := not R_rd.dsgn_to_out.handsh;
			   S.dsgn_to_out.data(2*G_DWIDTH -1 downto 0)  := S.reg_fifo_to_out.data(2*G_DWIDTH -1 downto 0);
			   S.dsgn_to_out.dextra                        := S.reg_fifo_to_out.dextra;
			   S.dsgn_to_out.possition                     := S.reg_fifo_to_out.possition;				
         end if;
      end if;
 
      R_rd_in <= S;
   end process;

	w_out_to_fifo <= R_rd.out_to_fifo;
	w_out_to_reg1 <= R_rd.out_to_reg1;

	w_to_out      <= R_rd.dsgn_to_out;


   reg_out_inst_1 : ea_reg
   generic map(
      G_DNUM      => 2,
      G_DWIDTH    => G_DWIDTH,
      G_DEXTRA    => C_DEXTRA_MAX,
		G_USE_EXTR  => 1,
		G_USE_POSS  => 1)
   port map(
      i_clk      => s_axis_aclk,
      i_rst      => not(s_axis_arst_n),

      i_data     => w_to_out,
      o_ack      => w_from_out,

      o_data     => w_oreg_to_out,
      i_ack      => i_ack);

   o_pix.data(o_pix.data'high downto 2*G_DWIDTH) <= (others => '0');
   o_pix.data(  2*G_DWIDTH -1 downto 0)          <= w_oreg_to_out.data(2*G_DWIDTH -1 downto 0);
   o_pix.dextra                                  <= w_oreg_to_out.dextra;
   o_pix.possition                               <= w_oreg_to_out.possition;
   o_pix.handsh                                  <= w_oreg_to_out.handsh;

end Behavioral;
