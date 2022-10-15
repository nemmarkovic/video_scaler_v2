library ieee;
    use ieee.std_logic_1164.all;

-- Package Declaration Section
package p_fifo is

   type t_wr_2_fifo is record
      wr_req   : std_logic;
      data     : std_logic_vector(7 downto 0);
   end record t_wr_2_fifo;  
   
   type t_fifo_2_wr is record
      full     : std_logic;
      wr_ack   : std_logic;
   end record t_fifo_2_wr; 

   type t_fifo_2_rd is record
      rd_ack   : std_logic; -- instead of valid Hand Shake
      data     : std_logic_vector(7 downto 0);
   end record t_fifo_2_rd; 

   type t_rd_2_fifo is record
      rd_req   : std_logic;
   end record t_rd_2_fifo; 

   function Bitwise_AND (
      i_vector : in std_logic_vector(3 downto 0))
   return std_logic;
   
end package p_fifo;
 
-- Package Body Section
package body p_fifo is
 
  function Bitwise_AND (
    i_vector : in std_logic_vector(3 downto 0)
    )
    return std_logic is
  begin
    return (i_vector (0) and i_vector (1) and i_vector (2) and i_vector (3));
  end;
 
end package body p_fifo;