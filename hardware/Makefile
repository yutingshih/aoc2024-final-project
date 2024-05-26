xbus: output
	vcs -R -sverilog ./test/XBus_tb.sv -debug_access+all -full64 +define+USE_STUB

GIN: output
	python ./test/GIN_test_data/auto_gen.py
	vcs -R -sverilog ./test/GIN_tb.sv -debug_access+all -full64 +define+USE_STUB

output:
	mkdir -p output


.SILENT:
clean:
	-rm -f *.log
	-rm -f simv
	-rm -f ucli.key
	-rm -f novas.*
	-rm -f novas_dump.*
	-rm -f *.fsdb
	-rm -rf BSSLib.lib++
	-rm -rf csrc
	-rm -rf nWaveLog
	-rm -rf simv.daidir
	-rm -rf output
	