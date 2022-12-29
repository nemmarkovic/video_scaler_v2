-----------------------------------------------------------------------------------
-- file name   : ea_coef_pos_calc
-- module      : bilinear_flt
-- author      : Nebojsa Markovic
-- emaill      : mnebojsa.etf@gmail.com
-- date        : september 1st, 2021
-----------------------------------------------------------------------------------
-- description :
--        Based on the input pixel pair, pixel pair possition in the original image
--        and scaling factor gives resultat pixels for the result image
-----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

    use work.p_handshake.all;

library ieee_proposed;
    use ieee_proposed.fixed_pkg.all;

library common_lib;
    use common_lib.p_common.all;

entity cf_indx_calc is
   generic(
      G_TYPE          : string                :=  "V"; --"V", "H"
      G_IN_SIZE       : integer               :=  256;
      G_OUT_SIZE      : integer               := 1280;
      G_PHASE_NUM     : integer range 2 to C_MAX_PHASE_NUM := 4;
      G_DWIDTH        : integer range 1 to 64 :=    8);
   port ( 
      --! input clk
      i_clk        : in  std_logic;
      --! input reset
      i_rst        : in  std_logic;
      --! input row/comlmun position valid
      i_data       : in  t_data;
      o_ack        : out t_ack;
      -- next module ready to accept filter outputs
      i_ack        : in  t_ack;
      o_data       : out t_data;
      o_cf         : out t_cf_indx_array);
   end cf_indx_calc;

architecture Behavioral of cf_indx_calc is

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

   constant c_phase_width : positive                           := clog2(G_PHASE_NUM);
   constant c_phase_num   : positive                           := 2**c_phase_width;
   constant c_ones        : std_logic_vector(0 to c_phase_num) := (others => '1');
   constant c_zeros       : std_logic_vector(0 to c_phase_num) := (others => '0');

   -- cf index calc cell signals
 --  signal l_mux_sel          : std_logic_vector(c_phase_num -1 downto 0);
   signal l_ipos_as_expected : std_logic_vector(0 to c_phase_num);
 
   type t_cf_width_array is array (0 to c_phase_num) of std_logic_vector(c_phase_width -1 downto 0);
   signal w_cf_indx        : t_cf_width_array;

   type t_pix_pos is array (0 to c_phase_num) of std_logic_vector(11 -1 downto 0);
   signal w_next_start_pix :  t_pix_pos;
   signal w_expected_pos   :  t_pix_pos;
   
   signal l_indx_valid : std_logic_vector(0 to c_phase_num -1);


------------------------------------------------------------------------
------------------------------------------------------------------------
   constant C_DNUM_in   : natural range 1 to   8 :=  2;

   type t_reg is record
      in_data       : t_data;
      in_data_ack   : t_ack;
      odata         : t_data;
      oack          : t_ack;
      cf_indx       : t_cf_width_array;
      active        : std_logic;
--      indx_valid    : std_logic_vector(0 to c_phase_num -1);
   end record t_reg;  

   constant t_reg_rst : t_reg := (
      in_data       => t_data_rst,
      in_data_ack   => t_ack_rst,
      active        => '0',
      odata         => t_data_rst,
      oack          => t_ack_rst,
      cf_indx       => (others => (others => '0')));

   signal R, R_in   : t_reg;

   alias a_eof    : std_logic is R.in_data.dextra(1);
   alias a_last   : std_logic is R.in_data.dextra(0);

   type t_reg_out is record
      dout       : t_data;
      dout_ack   : t_ack;
      start_pos  : std_logic_vector(11-1 downto 0);
      start_pos1  : std_logic_vector(11-1 downto 0);
		active     : boolean;
		ready_for_next_pix : boolean;
   end record t_reg_out;  

   constant t_reg_out_rst : t_reg_out := (
      dout       => t_data_rst,
      dout_ack   => t_ack_rst,
      start_pos  => (others => '0'),
      start_pos1  => (others => '0'),
		active     => false,
		ready_for_next_pix => false);

   signal R_out, R_out_cmb   : t_reg_out;
		
   signal w_inreg_data      : t_data;
   signal w_inreg_akc       : t_ack;

   signal w_outreg_idata     : t_data;
   signal w_outreg_oakc      : t_ack;
------------------------------------------------------------------------
------------------------------------------------------------------------
begin

-- Register process
reg_in : process(i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_rst = '1') then
             R <= t_reg_rst;
         else
             R <= R_in;
             R.active <= '1';
         end if;
      end if;
   end process;

-- Function comb process
fnc: process(all)
      variable S : t_reg;
   begin
      S := R;

      if R.active = '1' then

         -- set ack full signal if all cells return info the poss is corresponding
         --S.in_data_ack.full := R_out_cmb.ready_for_next_pix;

			-- uzmi novi pix sa ulaza
         if (i_data.handsh /= R.in_data_ack.ack) and (R.in_data_ack.full = '0') and (R_out_cmb.ready_for_next_pix) then
            S.in_data_ack.ack := i_data.handsh;
            S.in_data_ack.full:= '1';

            S.in_data.data(C_DNUM_in * G_DWIDTH -1 downto 0) := i_data.data(C_DNUM_in * G_DWIDTH -1 downto 0);
            S.in_data.dextra                                 := i_data.dextra;
            S.in_data.possition                              := i_data.possition;
         end if;

         if S.in_data_ack.full = '1' then
            if ((i_ack.ack = R.odata.handsh) and (i_ack.full = '0')) then
               S.odata.handsh := not R.odata.handsh;
               S.odata.data   := S.in_data.data;
            end if;
         end if;
 
         S.cf_indx := w_cf_indx;
      end if;
      R_in <= S;
end process;
o_ack <= R.in_data_ack;
-----------------------------------------
-- combinational logic between two reg stages
-----------------------------------------
cf_calc_cell_gen: for gen_cell_num in 0 to c_phase_num generate
      type t_cell_num_array is array (0 to c_phase_num) of std_logic_vector(c_phase_width downto 0);
      signal l_cell_num        : t_cell_num_array;
   begin
   -----------------------------------------
   -- coef calculate cell
   -----------------------------------------
   l_cell_num(gen_cell_num) <= std_logic_vector(to_unsigned(gen_cell_num, c_phase_width +1));
   coef_pos_calc_cell_i: entity work.cf_calc_cell
      generic map(
         G_IN_SIZE        => G_IN_SIZE,
         G_OUT_SIZE       => G_OUT_SIZE,
         G_PHASE_NUM      => c_phase_num,
         G_DWIDTH         => G_DWIDTH)
      port map( 
         i_start_pos       => R_out.start_pos,
         i_cell_num        => l_cell_num(gen_cell_num),
         --output pixel data 
         o_expected_pos    => w_expected_pos(gen_cell_num),
         o_start_pos       => w_next_start_pix(gen_cell_num),
         o_cf_num          => w_cf_indx(gen_cell_num));

      -- is equal to i_pos	
      l_ipos_as_expected(gen_cell_num) <= '1' when ((w_expected_pos(gen_cell_num) xor R_out.start_pos1) /= c_zeros) else '0';
   end generate;
-----------------------------------------------
-- uporedi l_start_pos  i vidi v/h opcije
	
-- Register process
reg_out : process(i_clk)
   begin
      if rising_edge(i_clk) then
         if (i_rst = '1') then
             R_out <= t_reg_out_rst;
         else
             R_out <= R_out_cmb;
             R_out.active <= true;
         end if;
      end if;
   end process;

-- Function comb process
out_fnc: process(all)
      type t_lreg is record
         mux_sel : std_logic_vector(c_phase_num -1 downto 0);
      end record t_lreg;

      constant t_lreg_rst : t_lreg := (
         mux_sel       => (others => '0'));

      variable V : t_lreg;
      variable S : t_reg_out;
   begin
      S := R_out;
      V := t_lreg_rst;

      if R.active = '1' then

         S.ready_for_next_pix := (l_ipos_as_expected /= c_ones);

         if (i_ack.ack = R_out.dout.handsh) and (i_ack.full = '0') then

            S.dout.handsh    := not R_out.dout.handsh;
			S.dout.data      := (others => '0');  -- preuzmi podatak zaregistrovan na ulazu
			S.dout.dextra    := (others => '0');  -- mjau mjau logicno
			S.dout.possition := (others => '0');  -- preuzmi sledecu poziciju sa mogula u zavisnosti od toga koja se bira


            V.mux_sel := (others => '0');
            cf_xor_gen: for gen_cell_num in 1 to c_phase_num loop
               if (l_ipos_as_expected(gen_cell_num) xor l_ipos_as_expected(gen_cell_num -1)) = '1' then
                  V.mux_sel(gen_cell_num -1) := '1';
               end if;
            end loop;

-- zakasni dodjelu za takt
            if S.ready_for_next_pix then
               cf_spos_gen: for gen_cell_num in 0 to c_phase_num -1 loop
                  if (V.mux_sel(gen_cell_num )) = '1' then
                     S.start_pos       := w_next_start_pix(gen_cell_num +1);
                  end if;
               end loop;
            else
               S.start_pos       := w_next_start_pix(c_phase_num);
            end if;
           S.start_pos1 := R_out.start_pos;
         end if;
      end if;

      R_out_cmb <= S;
   end process;

-----------------------------------------
-- outputs assignment
-----------------------------------------

gf: for cell_num_gen in 0 to c_phase_num -1 generate
   o_cf(cell_num_gen).cf_indx       <= w_cf_indx(cell_num_gen);
   o_cf(cell_num_gen).cf_indx_valid <= '1';--R.indx_valid(cell_num_gen);
end generate;


end Behavioral;
