# Makefile for GHDL-simulering av Game of Life-moduler
# Anvandning: make tb_<modname>    (kor en testbank)
#             make wave_<modname>  (oppna VCD i GTKWave)
#             make clean

GHDL = ghdl
STD = --std=08
WORK = --workdir=work
FLAGS = $(STD) $(WORK)

# Lista alla kallor har nar modulerna skapas
SRCS = vhdl/clk25_div.vhd vhdl/vga_timing.vhd vhdl/grid_bram.vhd vhdl/top.vhd

work:
	mkdir -p work

# Generisk regel: make tb_foo kor testbanken tb_foo.vhd mot motsv. modul i vhdl/
tb_%: work tb/tb_%.vhd $(SRCS)
	$(GHDL) -a $(FLAGS) $(SRCS) tb/tb_$*.vhd
	$(GHDL) -e $(FLAGS) tb_$*
	$(GHDL) -r $(FLAGS) tb_$* --vcd=tb_$*.vcd --stop-time=100ms

wave_%: tb_%.vcd
	gtkwave tb_$*.vcd &

clean:
	rm -rf work *.vcd *.cf *.o

.PHONY: clean
