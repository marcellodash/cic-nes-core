--*************************************************************
--  cic
--  Copyright 2018 René Richard
--  DEVICE : 
--*************************************************************
--
--  Description:
--		This is a VHDL implementation of an NES CIC lockout chip
--*************************************************************
--
-- https://wiki.nesdev.com/w/index.php/CIC_lockout_chip_pinout
--                 ----_----
-- Data Out 01 <-x|P0.0  Vcc|--- 16 +5V
-- Data In  02 x->|P0.1 P2.2|x-x 15 Gnd
-- Seed     03 x->|P0.2 P2.1|x-x 14 Gnd
-- Lock/Key 04 x->|P0.3 P2.0|x-x 13 Gnd
-- N/C      05 x- |Xout P1.3|<-x 12 Gnd/Reset speed B
-- Clk in   06  ->|Xin  P1.2|<-x 11 Gnd/Reset speed A
-- Reset    07  ->|Rset P1.1|x-> 10 Slave CIC reset
-- Gnd      08 ---|Gnd  P1.0|x-> 09 /Host reset
--                 ---------
--
--P0.x = I/O port 0
--P1.x = I/O port 1
--P2.x = I/O port 2
--Xin  = Clock Input
--Xout = Clock Output
--Rset = Reset
--Vcc  = Input voltage
--Gnd  = Ground
--->|  = input
--<-|  = output
---x|  = unused as input
--x-|  = unused as output
-----  = Neither input or output

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cic is 

	port (
		--CTRL
		Clk_p				:  in		std_logic;
		Reset_p			:	in		std_logic;
		
		--Port 0
		DataOut_p		:	out	std_logic;
		DataIn_p			:	in		std_logic;
		Seed_p			:  in		std_logic;
		nKey_p			:	in		std_logic;
		
		--Port 1
		HostReset_p		:  out	std_logic;
		SlaveReset_p	:	out	std_logic;
		ResetA_p			:	in		std_logic;
		ResetB_p			:	in 	std_logic;
		
		--Test
		PC_p				:  out 	std_logic_vector(9 downto 0)
	);
end entity; 

architecture cic_a of cic is

--The CIC is a primitive 4-bit microcontroller. It contains the following registers:
--
--+-+         +-------+  +-------+-------+-------+-------+
--|C|         |   A   |  |       |       |       |       |
--+-+         +-+-+-+-+  +- - - - - - - - - - - - - - - -+
--            |   X   |  |       |       |       |       |
--        +---+-+-+-+-+  +- - - - - - - - - - - - - - - -+
--        |     P     |  |       |       |       |       |
--        | PH|   PL  |  +- - - - - - - - - - - - - - - -+
--+-------+-+-+-+-+-+-+  |       |       |       |       |
--|         IC        |  +- - - - - - - -R- - - - - - - -+
--+-+-+-+-+-+-+-+-+-+-+  |       |       |       |       |
--|                   |  +- - - - - - - - - - - - - - - -+
--+- - - - - - - - - -+  |       |       |       |       |
--|                   |  +- - - - - - - - - - - - - - - -+
--+- - - - -S- - - - -+  |       |       |       |       |
--|                   |  +- - - - - - - - - - - - - - - -+
--+- - - - - - - - - -+  |       |       |       |       |
--|                   |  +- - - - - - - - - - - - - - - -+
--+-+-+-+-+-+-+-+-+-+-+
--
--A  = 4-bit Accumulator
--C  = Carry flag
--X  = 4-bit General register
--P  = Pointer, used for memory access
--PH = Upper 2-bits of P
--PL = Lower 4-bits of P, used for I/O
--IC = Instruction counter, to save some space; it counts in a polynominal manner instead of linear manner
--S  = Stack for the IC register
--R  = 32 nibbles of RAM
--There are also 512 (768 for the 3195A) bytes of ROM, where the executable code is stored.

-- types
	--FSM
	type cpu_cycles_type IS (cpuLoad, cpuRead, cpuModify, cpuWrite);
	
	--stack 
	type cic_stack_typ is array (0 to 3) of std_logic_vector(9 downto 0);
	
-- exposed registers and signals
	signal carry_s			:  std_logic;
	signal acc_s			:	std_logic_vector(4 downto 0);
	signal xreg_s			:	std_logic_vector(3 downto 0);
	signal ptr_s			:	std_logic_vector(5 downto 0);
	signal pc_s				:	std_logic_vector(9 downto 0);
	
-- internal
	signal temp_reg_s		: 	std_logic_vector(3 downto 0);
	
	signal temp_pc_s		:  std_logic_vector(9 downto 0);
	signal stack_s			:  cic_stack_typ;
	signal cpu_state_s	: 	cpu_cycles_type;
	signal inc_pc_s		:  std_logic;
	signal load_pc_s		:	std_logic;
	
	
begin

-- the program counter is not a linear counter, it counts like this every 4 cycles
--073: 30      ldi 0
--079: 20      lbli 0
--03c: 4a      s		; [1:0] := 0
--05e: 32      ldi 2
--02f: 21      lbli 1
--057: 46      out	; P1 := 2	// reset host and key
--06b: 00      nop
--075: 30      ldi 0
--03a: 46      out	; P1 := 0	// run key
--01d: 20      lbli 0	; L := 0
--00e: 31      ldi 1
--007: 46      out	; P0 = 1
--043: 3e      ldi e	; A := e
--01110011
--01111001
--00111100
--01011110
--00101111
--01010111

	--external signals
	PC_p <= pc_s;

	program_counter: process( Clk_p, Reset_p )
	begin
		if Reset_p = '0' then
			pc_s <= ( others => '0');
			
		elsif ( load_pc_s = '0' ) then
			pc_s <= temp_pc_s;
			
		elsif (rising_edge(Clk_p)) then
			
			if inc_pc_s = '1' then
				pc_s(5 downto 0) <= pc_s(6 downto 1);
				if pc_s(1) = pc_s(0) then
					pc_s(6) <= '1';
				else
					pc_s(6) <= '0';
				end if;
			end if;
		else
			pc_s <= pc_s;
		end if;
	end process;
	
	cpu_state: process( Clk_p, Reset_p )
	begin
		if Reset_p = '0' then
			cpu_state_s <= cpuLoad;
		elsif (rising_edge(Clk_p)) then
			inc_pc_s <= '0';
			case cpu_state_s is
				--Q1
				when cpuLoad =>
					inc_pc_s <= '1';
					cpu_state_s <= cpuRead;
				--Q2
				when cpuRead =>
					cpu_state_s <= cpuModify;
				--Q3
				when cpuModify =>
					cpu_state_s <= cpuWrite;
				--Q4
				when cpuWrite =>
					cpu_state_s <= cpuLoad;
			end case;
		end if;
	end process;

end cic_a;