library std;
use std.env.all;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cic_tb is
end cic_tb;

architecture rtl of cic_tb is
		--CTRL
	signal	Clk				: std_logic := '0';
	signal	Reset				: std_logic := '0';
		
		--Port 0
	signal	DataOut			: std_logic;
	signal	DataIn			: std_logic;
	signal	Seed				: std_logic;
	signal	nKey				: std_logic;
		
		--Port 1
	signal	HostReset		: std_logic;
	signal	SlaveReset		: std_logic;
	signal	ResetA			: std_logic;
	signal	ResetB			: std_logic;
		
		--Test
	signal	PC					: std_logic_vector(9 downto 0);
	signal 	Accumulator		: std_logic_vector(4 downto 0);
	
	-- constants
	constant CLK_PERIOD : time := 250 ns;-- 4MHz
	
begin
	
	cic_u0: entity work.cic
		port map(
			Clk_p => Clk,
			Reset_p => Reset,
			DataOut_p => DataOut,
			DataIn_p => DataIn,
			Seed_p => Seed,
			nKey_p => nKey,
			HostReset_p => HostReset,
			SlaveReset_p => SlaveReset,
			ResetA_p => ResetA,
			ResetB_p => ResetB,
			PC_p => PC,
			Accumulator_p => Accumulator
		);
	
	--clock generation
	clk <= not clk after CLK_PERIOD/2;
	
	sim : process
	begin
		
		wait for 1 us;
		Reset <= '1';
		
	end process;
	
end architecture;