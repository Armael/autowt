all:
	dune build src/autowt.exe

loop:
	dune build -w src/autowt.exe

clean:
	dune clean

.PHONY: all loop
