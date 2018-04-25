all: simple

simple: simple.nim simple_pb.nim
	nim c $<

%_pb.nim: %.proto
	../../nimpb/compiler/nimpb_build -I=. --out=. $<
