library ieee;
    use ieee.std_logic_1164.all;

-- Package Declaration Section
package p_handshake is

   constant C_FIFO_DEPTH : natural := 2048;
   constant C_POS_WIDTH  : natural :=   11;
   constant C_DWIDTH_MAX : natural :=   64;
   constant C_DEXTRA_MAX : natural :=    2;

--   type darray is array (positive range <>) of std_logic_vector;

   type t_data is record
      handsh    : std_logic;
      dextra    : std_logic_vector(C_DEXTRA_MAX -1 downto 0);
      data      : std_logic_vector(C_DWIDTH_MAX -1 downto 0);--darray;
      possition : std_logic_vector(C_POS_WIDTH  -1 downto 0);
   end record t_data;  
 
   constant t_data_rst : t_data := (
      handsh    => '0',
      dextra    => (others => '0'),
      data      => (others => '0'),
      possition => (others => '0'));
   
 
   type t_ack is record
      full     : std_logic;
      ack      : std_logic;
   end record t_ack; 

   constant t_ack_rst : t_ack := (
      full      => '0',
      ack       => '0');
 
end package p_handshake;
 
-- Package Body Section
package body p_handshake is

end package body p_handshake;
