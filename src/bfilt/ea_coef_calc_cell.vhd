-----------------------------------------------------------------------------------
-- file name   : cf_calc_cell
-- module      : bilinear_flt
-- author      : Nebojsa Markovic
-- emaill      : mnebojsa.etf@gmail.com
-- date        : november 10th, 2021
-----------------------------------------------------------------------------------
-- description :
-----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ieee_proposed;
    use ieee_proposed.fixed_pkg.all;

library common_lib;
    use common_lib.p_common.all;

entity cf_calc_cell is
   generic(
      --! Relevan input size (width/hight)
      G_IN_SIZE    : integer               :=  446;
      --! Result size in the dimension
      G_OUT_SIZE   : integer               := 2048;
      --! Max number of interlived spots between two input pixels
      --! Also, a number of calc cells in the design
      G_PHASE_NUM  : integer range 2 to C_MAX_PHASE_NUM := 4;
      --! Pixel intesity data width
      G_DWIDTH     : integer range 1 to 64 :=    8);
   port ( 
      --! Possition of first output pixel por the cycle
      i_start_pos  : in  std_logic_vector(11 -1 downto 0);
      --! cell number, takes values 0-G_PHASE_NUM -1
      i_cell_num   : in  std_logic_vector(0 to clog2(G_PHASE_NUM));
      --! Valid coeficient number (used to select one of
      --! G_PHASE_NUM coeficients) in next step module
      o_expected_pos: out std_logic_vector(11 -1 downto 0);
      --! next start possition for output pix candidat
      o_start_pos  : out std_logic_vector(11 -1 downto 0);
      --! number of coefficient to select for calculations
      o_cf_num     : out std_logic_vector(clog2(G_PHASE_NUM)-1 downto 0));
   end cf_calc_cell;

architecture Behavioral of cf_calc_cell is
   -- expect number of pfases to be pow of 2 (to be able
   -- to optimise design for less resource usage)
   constant c_phase_num : positive := 2**clog2(G_PHASE_NUM);
   -- number of bits required to represent all phases
   constant c_precision : positive := clog2(G_PHASE_NUM);
   -- scale factor SF = G_IN_SIZE* c_phase_num / G_OUT_SIZE
   constant c_sf_up : ufixed(C_SF_WIDTH -1 downto -c_precision) := 
                   resize(((to_ufixed(G_IN_SIZE* c_phase_num, 18, -1)) /
                          ( to_ufixed(G_OUT_SIZE -1, 12, -1))), C_SF_WIDTH -1, -c_precision);

   constant c_sf_down : ufixed(C_SF_WIDTH -1 downto -c_precision) := 
                   resize(((to_ufixed(G_IN_SIZE* c_phase_num, 18, -1)) /
                          ( to_ufixed(G_OUT_SIZE, 12, -1))), C_SF_WIDTH -1, -c_precision);

   function f_mul_round(start_pos : std_logic_vector) return std_logic_vector is
   begin
      if (G_OUT_SIZE >= G_IN_SIZE) then
         return std_logic_vector(resize((to_ufixed(to_integer(unsigned(start_pos)),11, -c_precision)*   c_sf_up), 11 + c_precision -1, -0));
      else
         return std_logic_vector(resize((to_ufixed(to_integer(unsigned(start_pos)),11, -c_precision)* c_sf_down), 11 + c_precision -1, -0));      
      end if;
   end function;


   signal l_next_start_pos : std_logic_vector(11 -1 downto 0);
   signal l_pos_mul_sf     : std_logic_vector(11 + c_precision -1 downto 0);
   signal l_div_g_no_phase : std_logic_vector(11               -1 downto 0);
   signal l_mod_g_no_phase : std_logic_vector(     c_precision -1 downto 0);
begin
   -- add cell num to start possition
   l_next_start_pos <= std_logic_vector(unsigned(i_start_pos) + unsigned(i_cell_num));
   -- multiply the l_next_start_pos with scale factor and round the result
   l_pos_mul_sf     <= f_mul_round(l_next_start_pos);
   -- since G_PHASE_NUM is pow of 2, l_pos_mul_sf mod G_PHASE_NUM can be
   -- performed taking just G_PHASE_NUM'width lower bits from l_pos_mul_sf
   l_mod_g_no_phase <= l_pos_mul_sf(     c_precision -1 downto 0);
   -- since G_PHASE_NUM is pow of 2, l_pos_mul_sf mod G_PHASE_NUM can be
   -- performed taking just biths higher ftom G_PHASE_NUM'width from l_pos_mul_sf
   l_div_g_no_phase <= l_pos_mul_sf(11 + c_precision -1 downto c_precision);

---------------------------------------------------------------
---------------------------------------------------------------
   o_expected_pos   <= l_div_g_no_phase;
   o_start_pos      <= l_next_start_pos;
   o_cf_num         <= l_mod_g_no_phase;
end Behavioral;
