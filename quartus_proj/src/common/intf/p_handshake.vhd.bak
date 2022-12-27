library ieee;
    use ieee.std_logic_1164.all;

-- Package Declaration Section
package p_handshake is

   type darray is array (positive range <>) of std_logic_vector;

   type t_data_d is record
      handsh   : std_logic;
      data     : std_logic_vector(2*8 +3 -1 downto 0);
   end record t_data_d; 

   type t_data is record
      handsh   : std_logic;
      dextra   : std_logic_vector;
      data     : darray;--(8 +3 -1 downto 0);
   end record t_data;  
   
   type t_ack is record
      full     : std_logic;
      ack      : std_logic;
   end record t_ack; 
   
end package p_handshake;
 
-- Package Body Section
package body p_handshake is

end package body p_handshake;