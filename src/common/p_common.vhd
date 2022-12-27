library ieee;
    use ieee.STD_LOGIC_1164.ALL;
    use ieee.math_real.ALL;


package p_common is

   function clog2(x : natural) return natural;

   constant C_MAX_IMAGE_DIM : positive := 2048;
   constant C_SF_WIDTH      : positive := integer(ceil(log2(real(C_MAX_IMAGE_DIM))) +1.0);
   constant C_MAX_PHASE_NUM : positive := 64;

   type t_in_pix is record
      valid : std_logic;
      pix0  : std_logic_vector( 8-1 downto 0);
      pix1  : std_logic_vector( 8-1 downto 0);
      pos   : std_logic_vector(11-1 downto 0);
      last  : std_logic; 
      sof   : std_logic;
   end record t_in_pix;

   constant t_in_pix_rst : t_in_pix :=(
      valid => '0',
      pix0  => (others => '0'),
      pix1  => (others => '0'),
      pos   => (others => '0'),
      last  => '0',
      sof   => '0');

   type t_cf_indx is record
      cf_indx        : std_logic_vector(integer(ceil(log2(real(4))))-1 downto 0);
      cf_indx_valid  : std_logic; 
   end record t_cf_indx;

   type t_cf_indx_array is array (0 to 4 -1) of t_cf_indx;

   type t_byte_array is array (0 to 4 -1) of std_logic_vector(8 -1 downto 0);

--   type t_dinfo is record
--      data  : t_byte_array;
--      last  : std_logic_vector(0 to 4 -1); 
--      sof   : std_logic_vector(0 to 4 -1);
--   end record t_dinfo;

   type t_out_pix is record
      valid : std_logic;
      pix   : std_logic_vector(8 -1 downto 0);
      last  : std_logic; 
      sof   : std_logic;
   end record t_out_pix;

   constant t_out_pix_rst : t_out_pix :=(
      valid =>  '0',
      pix   => (others => '0'),
      last  =>  '0',
      sof   =>  '0');

   type t_out_pix_array is array (0 to 4 -1) of t_out_pix;

   type t_in_mux_array is array (0 to 2 -1) of t_out_pix_array;
end package p_common;

package body p_common is
   -----------------------------------------------------------------------------
   -- Logarithm base 2 with rounding up.
   -----------------------------------------------------------------------------
   function clog2(x : natural) return natural is
   begin
      return integer(ceil(log2(real(x))));
   end function;
end package body;