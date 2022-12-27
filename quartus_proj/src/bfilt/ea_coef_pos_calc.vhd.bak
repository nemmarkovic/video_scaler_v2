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
      G_TYPE          : string                := "V"; --"V", "H"
      G_IN_SIZE       : integer               :=  256;
      G_OUT_SIZE      : integer               := 1280;
      G_PHASE_NUM     : integer range 2 to C_MAX_PHASE_NUM := 4;
      G_DWIDTH        : integer range 1 to 64 :=    8);
   port ( 
      --! input clk
      i_clk       : in  std_logic;
      --! input reset
      i_rst       : in  std_logic;
      --! input row/comlmun position valid
      i_data      : in  t_data(data(2*G_DWIDTH +3 -1 downto 0));
      i_poss      : in  std_logic_vector(11-1 downto 0);
      o_ack       : out t_ack;
      -- next module ready to accept filter outputs
      i_ack        : in  t_ack;
      o_data       : out t_data(data(2*G_DWIDTH +3 -1 downto 0));
      o_cf         : out t_cf_indx_array);
   end cf_indx_calc;

architecture Behavioral of cf_indx_calc is

component reg is
   generic(
      G_EXWIDTH: natural                :=  0;
      G_DNUM   : natural range 1 to   8 :=  1;
      G_DWIDTH : natural range 1 to 128 :=  8);
   port(
      i_clk       : in  std_logic;
      i_rst       : in  std_logic;

      i_data      : in  t_data(data(G_DWIDTH -1 downto 0));
      o_ack       : out t_ack;
      i_poss      : in  std_logic_vector(11-1 downto 0);

      o_data      : out t_data(data(G_DWIDTH -1 downto 0));
      i_ack       : in  t_ack);
   end component reg;

   constant c_phase_width : positive := clog2(G_PHASE_NUM);
   constant c_phase_num   : positive := 2**c_phase_width;

   -- cf index calc cell signals
   signal l_mux_sel          : std_logic_vector(c_phase_num -1 downto 0);
   signal l_ipos_as_expected : std_logic_vector(0 to c_phase_num);
 
   type t_cf_width_array is array (0 to c_phase_num) of std_logic_vector(c_phase_width -1 downto 0);
   signal w_cf_indx        : t_cf_width_array;

   type t_pix_pos is array (0 to c_phase_num) of std_logic_vector(11 -1 downto 0);
   signal w_next_start_pix :  t_pix_pos;
   signal w_expected_pos   :  t_pix_pos;
   
   signal l_indx_valid : std_logic_vector(0 to c_phase_num -1);


------------------------------------------------------------------------
------------------------------------------------------------------------
   constant C_EXWIDTH_in: natural                :=  3;
   constant C_DNUM_in   : natural range 1 to   8 :=  2;
   constant C_DWIDTH_in : natural range 1 to 128 :=  8;

   type t_reg is record
      in_data       : std_logic_vector(C_EXWIDTH_in + C_DNUM_in * C_DWIDTH_in -1 downto 0);
      in_data_ack   : t_ack;
      odata         : t_data(data(C_EXWIDTH_in + C_DNUM_in * C_DWIDTH_in -1 downto 0));
      oack          : t_ack;
      cf_indx       : t_cf_width_array;
      active        : std_logic;
      poss_as_expct : std_logic_vector(0 to c_phase_num);
      start_pos     : std_logic_vector(11 -1 downto 0);
      indx_valid    : std_logic_vector(0 to c_phase_num -1);
      poss          : std_logic_vector(11-1 downto 0);
   end record t_reg;  

   constant t_reg_rst : t_reg := (
      in_data       => (others => '0'),
      in_data_ack   => (full => '0', ack => '0'),
      active        => '0',
      odata         => (data => (others => '0'), handsh => '0'),
      oack          => (ack => '0', full => '0'),
      cf_indx       => (others => (others => '0')),
      poss_as_expct => (others => '0'),
      start_pos     => (others => '0'),
      indx_valid    => (others => '0'),
      poss          => (others => '0'));

   signal R, R_in   : t_reg;

   alias a_eof    : std_logic is R.in_data(C_EXWIDTH_in + C_DNUM_in * C_DWIDTH_in -1);
   alias a_last   : std_logic is R.in_data(C_EXWIDTH_in + C_DNUM_in * C_DWIDTH_in -2);
   alias a_dvalid : std_logic is R.in_data(C_EXWIDTH_in + C_DNUM_in * C_DWIDTH_in -3);
   
   signal w_inreg_data      : t_data(data(G_DWIDTH -1 downto 0));
   signal w_inreg_akc       : t_ack;

   signal w_outreg_idata     : t_data(data(G_DWIDTH -1 downto 0));
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
      type t_lreg is record
         mux_sel : std_logic_vector(c_phase_num -1 downto 0);
         ipos_coresponds_for_all_cells : std_logic;
      end record t_lreg;

      constant t_lreg_rst : t_lreg := (
         mux_sel       => (others => '0'),
         ipos_coresponds_for_all_cells => '0');

      variable S : t_reg;
      variable V : t_lreg;
   begin
      S := R;

      V := t_lreg_rst;

      if R.active = '1' then

         V.ipos_coresponds_for_all_cells := and(l_ipos_as_expected);

         if i_data.handsh /= R.in_data_ack.ack then
            if R.in_data_ack.full = '0' then
               S.in_data_ack.ack := i_data.handsh;
               S.in_data_ack.full:= '1';
               S.in_data         := i_data.data;
               S.poss            := i_poss;
            end if;
         end if;
         -- set ack full signal if all cells return info the poss is corresponding
         S.in_data_ack.full := V.ipos_coresponds_for_all_cells;  -- or R.in_data_ack.full;--(?  R.in_data_ack.full)

         V.mux_sel := (others => '0');
         cf_xor_gen: for gen_cell_num in 1 to c_phase_num loop
            if (l_ipos_as_expected(gen_cell_num) xor l_ipos_as_expected(gen_cell_num -1)) = '1' then
               V.mux_sel(gen_cell_num -1) := '1';
            end if;
         end loop;


         if V.ipos_coresponds_for_all_cells = '1' then
            S.start_pos       := w_next_start_pix(c_phase_num);
--            l_start_pos_valid <= '1';
         else
            cf_spos_gen: for gen_cell_num in 0 to c_phase_num -1 loop
               if (l_mux_sel(gen_cell_num )) = '1' then
                  S.start_pos       := w_next_start_pix(gen_cell_num +1);
--                  l_start_pos_valid <= '1';
               end if;
            end loop;
         end if;

         if S.in_data_ack.full = '1' then
            if ((i_ack.ack = R.odata.handsh) and (i_ack.full = '0')) then
               S.odata.handsh := not R.odata.handsh;
               S.odata.data   := S.in_data;
            end if;
         end if;
 
         S.cf_indx := w_cf_indx;
 
         R_in <= S;
      end if;
end process;

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
         i_start_pos       => R.start_pos,
         i_cell_num        => l_cell_num(gen_cell_num),
         --output pixel data 
         o_expected_pos    => w_expected_pos(gen_cell_num),
         o_start_pos       => w_next_start_pix(gen_cell_num),
         o_cf_num          => w_cf_indx(gen_cell_num));

      -- is equal to i_pos
      l_ipos_as_expected(gen_cell_num) <= nor(w_expected_pos(gen_cell_num) xor R.poss) and a_dvalid;
   end generate;



-----------------------------------------
-- outputs assignment
-----------------------------------------

gf: for cell_num_gen in 0 to c_phase_num -1 generate
   o_cf(cell_num_gen).cf_indx       <= w_cf_indx(cell_num_gen);
   o_cf(cell_num_gen).cf_indx_valid <= R.indx_valid(cell_num_gen);
end generate;


end Behavioral;
