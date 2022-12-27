-----------------------------------------------------------------------------------
-- file name   : ea_bilinear_flt
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

--library ieee_proposed;
--    use ieee_proposed.fixed_pkg.all;

--library common_lib;
    use work.p_common.all;

entity ea_bilinear_flt is
   generic(
      G_TYPE          : string                := "V"; --"V", "H"
      G_IN_SIZE       : integer               :=  446;
      G_OUT_SIZE      : integer               := 2048;
      G_PHASE_NUM     : integer range 2 to  8 :=    4; --C_MAX_PHASE_NUM := 4;
      G_DWIDTH        : integer range 1 to 64 :=    8);
   port ( 
      -- input clk
      i_clk     : in  std_logic;
      -- input reset
      i_rst     : in  std_logic;
      -- ready to filter new data pair
      o_ack     : out  t_ack;
      i_poss    : in   natural range 0 to 4095;
      -- input pixel data
      -- pix0
      -- pix1
      -- last  : std_logic; 
      -- eof   : std_logic;
      i_pix      : in  t_data;
      -- next module ready to accept filter outputs
      i_ack     : in  t_ack;
      o_bank_sel : out std_logic_vector(11 downto 0);
      -- output pixel data
      -- data = pix0[G_MANTISA_WIDTH -1 : -G_PRESISION], 
      -- last  : std_logic; 
      -- eof   : std_logic;
      o_pix      : out t_data);
   end ea_bilinear_flt;


architecture Behavioral of ea_bilinear_flt is
   signal w_cf_calc_indx_ready_o           : std_logic;
   signal w_clc_pix_to_rpc                 : t_data;
--   signal w_cf_calc_indx_ipos_ready_o      : std_logic;
--   signal w_cf_calc_indx_start_pos_valid_o : std_logic;
--   signal w_cf_calc_indx_start_pos_ready_o : std_logic;
   signal w_cf_calc_indx_cf_o              : t_cf_indx_array;
--
   signal w_res_pix_calc_cf_i              : t_cf_indx_array;
   signal w_rpc_ack_to_cic                 : t_ack;
--   signal w_res_pix_calc_pix_valid_i       : std_logic;

--   -- infering latch - fix this !!!!!!!!!!!!!!!!!!!!!!!!!!
--   signal i_start_pos_valid_reg : std_logic;
--   signal i_start_pos_reg       : std_logic_vector(11 -1 downto 0);
--
--   signal r_start : std_logic;
--   signal l_start_pos_reg : std_logic_vector(11-1 downto 0);
--   signal r_start_pos_reg : std_logic_vector(11-1 downto 0);


	signal w_bflt_to_prev_ack               : t_ack;

   signal w_bflt_to_next_data              : t_data;
   signal w_bflt_to_next_bank_sel          : std_logic_vector(11  downto 0);

begin

-----------------------------------------
-- coeficient index calculation module
-----------------------------------------
cf_indx_calc_i: entity work.cf_indx_calc
   generic map(
      G_IN_SIZE         => G_IN_SIZE,
      G_OUT_SIZE        => G_OUT_SIZE,
      G_PHASE_NUM       => G_PHASE_NUM,
      G_DWIDTH          => G_DWIDTH)
   port map( 
      i_clk             => i_clk,
      i_rst             => i_rst,
      o_ack             => w_bflt_to_prev_ack,
      i_data            => i_pix,
      i_ack             => w_rpc_ack_to_cic,
      o_data            => w_clc_pix_to_rpc,
      o_cf              => w_cf_calc_indx_cf_o);

-----------------------------------------
-- resulting pix calculation - filtering
-----------------------------------------
--   w_res_pix_calc_cf_i        <= w_cf_calc_indx_cf_o;
--
--res_pix_calc_i: entity work.res_pix_calc
--   generic map(
--      G_TYPE      => G_TYPE,
--      G_IN_SIZE   => G_IN_SIZE,
--      G_OUT_SIZE  => G_OUT_SIZE,
--      G_PHASE_NUM => G_PHASE_NUM,
--      G_DWIDTH    => G_DWIDTH)
--   port map(
--      i_clk       => i_clk,
--      i_rst       => i_rst,
--
--      o_ack       => w_rpc_ack_to_cic,
--      i_pix       => w_clc_pix_to_rpc,
--      i_cf        => w_res_pix_calc_cf_i,
--      i_ack       => i_ack,
--      o_pix       => w_bflt_to_next_data,
--      o_bank_sel  => w_bflt_to_next_bank_sel);
      
------------------------------------------------------------------------------------
-- output assignment
------------------------------------------------------------------------------------
   o_ack        <= w_bflt_to_prev_ack;

   o_pix        <= w_bflt_to_next_data;
   o_bank_sel   <= w_bflt_to_next_bank_sel;
end Behavioral;

