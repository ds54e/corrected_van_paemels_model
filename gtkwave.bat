@echo off
set vcd2fst="C:\Apps\gtkwave64\bin\vcd2fst.exe"
set gtkwave="C:\Apps\gtkwave64\bin\gtkwave.exe"
cd %~dp0
if exist waves.vcd (
  echo VCD2FST
  %vcd2fst% waves.vcd waves.fst
  del waves.vcd
)
%gtkwave% waves.fst
exit