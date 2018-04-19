all: writer reader

writer: writer.nim addressbook_pb.nim phonenumber_pb.nim
	nim c $<

reader: reader.nim addressbook_pb.nim phonenumber_pb.nim
	nim c $<

%_pb.nim: %.proto
	nimpb_build -I=. --out=. $<
