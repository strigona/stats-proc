-- $Id: movedata.sql,v 1.10.2.1 2002/12/26 00:39:01 nerf Exp $ --

INSERT INTO stubs
SELECT DISTINCT I.id, A.stub_id, L.nodecount, L.os_type,
	L.cpu_type, L.version
FROM logdata L, id_lookup I, all_stubs A
WHERE L.email = I.email AND
	L.stub_marks = A.stub_marks;

CREATE INDEX stubs_id ON stubs(id);
CREATE INDEX stubs_stub_id ON stubs(stub_id);
CREATE INDEX stubs_nodecount ON stubs(nodecount);
