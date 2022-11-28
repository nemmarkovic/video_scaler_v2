-----------------------------------------------------------------------------------
-- file name   : res_pix_calc
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
    use ieee.math_real.ALL;

    use work.p_handshake.all;

library common_lib;
    use common_lib.p_common.all;

library cf_lib;
    use cf_lib.p_coeff.all;

entity res_pix_calc is
   generic(
      G_TYPE          : string                := "V"; --"V", "H"
      G_CF_PREC       : natural               :=  0;
      G_IN_SIZE       : integer               :=  256;
      G_OUT_SIZE      : integer               := 1280;
      G_PHASE_NUM     : integer range 2 to C_MAX_PHASE_NUM := 4;
      G_DWIDTH        : integer range 1 to 64 :=    8);
   port ( 
      --! input clk
      i_clk       : in  std_logic;
      --! input reset
      i_rst       : in  std_logic;

      o_ack       : out t_ack;
      -- input pixel data
      -- pix0
      -- pix1
      -- last  : std_logic; 
      -- eof   : std_logic;
      i_pix       : in  t_data;

      i_cf        : in  t_cf_indx_array;
      -- output pixel data
      -- data = pix0[G_MANTISA_WIDTH -1 : -G_PRESISION], 
      -- last  : std_logic; 
      -- eof   : std_logic;
      i_ack      : in  t_ack;
      o_pix      : out t_out_pix_array;
      o_bank_sel : out std_logic_vector(11 downto 0));
   end res_pix_calc;

architecture Behavioral of res_pix_calc is

--   type t_dummy is array (0 to G_PHASE_NUM -1) of std_logic_vector(15 downto 0);
   type t_dummy is array (0 to (G_PHASE_NUM/2 -1) + (G_PHASE_NUM mod 2)) of std_logic_vector(48-1 downto 0);
   signal w_temp_res : t_dummy;
   signal w_result   : t_dummy;

   signal w_pix    : t_out_pix_array;
   signal w_ready  : std_logic_vector(0 to G_PHASE_NUM -1);

   type t_slv_array is array (0 to G_PHASE_NUM -1) of std_logic_vector(G_DWIDTH +2 -1 downto 0);
   signal w_pix_out : t_slv_array; 

   attribute use_dsp : string;
--   attribute use_dsp of l_p : signal is "yes";
--   attribute use_dsp of o_pix0    : signal is "no";
--   attribute use_dsp of o_pix1    : signal is "no";

   signal r_out_possition : unsigned(integer(ceil(log2(real(2048)))) -1 downto 0);
 
   type t_cf is array (0 to G_PHASE_NUM -1) of std_logic_vector(7 downto 0);
   signal s_iA_cf_indx : t_cf;
   signal s_iB_cf_indx : t_cf;

   signal r_ipix       : t_in_pix;
   signal r_pix_valid  : std_logic_vector(0 to G_PHASE_NUM -1);
   signal l_bank_sel   : unsigned(11 downto 0);
begin

--------------------------------------------------------
---- Gen valid process 
--------------------------------------------------------
cf_indx_gen: for i in 0 to (G_PHASE_NUM -1) generate
   process(all)
   begin
      if i_cf(i).cf_indx_valid = '1' then
         s_iA_cf_indx(i) <= coeff0(to_integer(unsigned(i_cf(i).cf_indx)));
         s_iB_cf_indx(i) <= coeff0(to_integer(unsigned(not(i_cf(i).cf_indx))));
      else
         s_iA_cf_indx(i) <= (others => '0');
         s_iB_cf_indx(i) <= (others => '0');
      end if;
   end process;
end generate;

gen_phase_dsp:
   for i in 0 to ((G_PHASE_NUM/2 -1) + (G_PHASE_NUM mod 2)) generate
      mul_cell0_i : entity work.mul_cell
         generic map (
            G_REG_IN => 0)
         port map (
            i_clk    => i_clk,
            i_rst    => i_rst,
            i_B      => i_pix.pix0,
            i_A      => s_iA_cf_indx(2*i   ),
            i_D      => s_iA_cf_indx(2*i +1),
            i_C      => (others => '0'),
            o_result => w_temp_res(i));
    
      mul_cell1_i : entity work.mul_cell
         generic map (
            G_REG_IN => 1)
         port map (
            i_clk    => i_clk,
            i_rst    => i_rst,
            i_B      => i_pix.pix1,
            i_A      => s_iB_cf_indx(2*i   ),
            i_D      => s_iB_cf_indx(2*i +1),
            i_C      => w_temp_res(i)(47 downto 19) & w_temp_res(i)(18 downto 0),
            o_result => w_result(i));


       w_pix(2*i   ).pix <= w_result(i)(G_DWIDTH + G_CF_PREC     -1 downto      G_CF_PREC);
       w_pix(2*i +1).pix <= w_result(i)(G_DWIDTH + G_CF_PREC +19 -1 downto 19 + G_CF_PREC);

   end generate;

------------------------------------------------------------------------------------------------------
-- !!!!!!!   This is fixed solution for vertical filter
--    implement this in better way using generic for V-H filter type
------------------------------------------------------------------------------------------------------
gen_vert_flt: if G_TYPE = "V" generate
   process(i_clk)
      variable vr_ipix       : t_in_pix;
      variable vr_ipix2      : t_in_pix;
   begin
      if rising_edge(i_clk) then
         if i_rst = '1' then
            r_ipix <= t_in_pix_rst;
            vr_ipix:= t_in_pix_rst;
            vr_ipix2:= t_in_pix_rst;
         else
            r_ipix   <= vr_ipix2;
            vr_ipix  := vr_ipix2;
            vr_ipix2 := i_pix;
         end if;
      end if;
   end process;
end generate;

gen_horisontal_flt: if G_TYPE = "H" generate
   process(i_clk)
--      variable vr_ipix       : t_in_pix;
--      variable vr_ipix2      : t_in_pix;
   begin
      if rising_edge(i_clk) then
         if i_rst = '1' then
--            r_ipix <= t_in_pix_rst;
--            vr_ipix:= t_in_pix_rst;
--            vr_ipix2:= t_in_pix_rst;
         else
--            r_ipix   <= vr_ipix2;
--            vr_ipix  := vr_ipix2;
--            vr_ipix2 := i_pix;
         end if;
      end if;
   end process;
end generate;


valid_proc: process(i_clk)
      variable vr_pix_valid  : std_logic_vector(0 to G_PHASE_NUM -1);
   begin
      if rising_edge(i_clk) then
         if i_rst = '1' then
            r_pix_valid <= (others => '0');
            vr_pix_valid := (others => '0');
         else
            r_pix_valid <= vr_pix_valid;
   
            for i in 0 to (G_PHASE_NUM -1) loop
               if i_cf(i).cf_indx_valid = '1' then
                  vr_pix_valid(i) := '1';
               else
                  vr_pix_valid(i) := '0';
               end if;
            end loop;
         end if;
      end if;
   end process;

reg_res_pix_gen: for i in 0 to (G_PHASE_NUM -1) generate

   reg_res_pix_i: entity work.reg_hs
      generic map(
         G_DWIDTH => G_DWIDTH +2)
      port map(
         i_clk   => i_clk,
         i_rst   => i_rst,
         i_data  => w_pix(i).pix & r_ipix.last & r_ipix.sof,
         i_valid => r_pix_valid(i),
         o_ready => w_ready(i),
         i_ready => i_ready,
         o_valid => o_pix(i).valid,
         o_data  => w_pix_out(i));

      o_pix(i).pix  <= w_pix_out(i)(G_DWIDTH +2 -1 downto 2);
      o_pix(i).last <= w_pix_out(i)(1);
      o_pix(i).sof  <= w_pix_out(i)(0);


reg_res_pix_i: entity work.reg
      generic map(
         G_DWIDTH => G_DWIDTH +2)
      port map(
         i_clk   => i_clk,
         i_rst   => i_rst,

         i_data      : in  t_data(data(G_DWIDTH -1 downto 0));
         o_ack       : out t_ack;

         o_data      : out t_data(data(G_DWIDTH -1 downto 0));
         i_ack       : in  t_ack);


   end generate;

------------------------------------------------------------
-- select signal
------------------------------------------------------------
      process(i_clk)
         variable v_do : std_logic;
         variable vl_bank_sel   : unsigned(11 downto 0);
      begin
         if rising_edge(i_clk) then
            if i_rst = '1' then
               l_bank_sel  <= (others => '0');
               vl_bank_sel := (others => '0');
               v_do := '0';
            else
               v_do := '0';
               vl_bank_sel := l_bank_sel;
               for i in 0 to G_PHASE_NUM -1 loop
                  if o_pix(i).valid = '1' and i_ready = '1' then
                     v_do := '1';
                  end if;
               end loop;
               if v_do = '1' then
                  l_bank_sel <= (vl_bank_sel +1) mod 2; -- 2 je broj banaka potreban (G_OUT/GIN) / G_PHASE_NUM
               end if;
            end if;
         end if;
      end process;
------------------------------------------------------------
------------------------------------------------------------


   o_ack      <= and(w_ready);
   o_bank_sel <= std_logic_vector(l_bank_sel);
end Behavioral;