#! /bin/sh

WORKDIR=$1

for PROJECTID in 25
do

OUTFILE=$WORKDIR/ogr_stublist${PROJECTID}
rm -f $OUTFILE

psql ogr <<EOF
	CREATE TEMP TABLE done_stubs (stub_marks varchar(22)) WITHOUT OIDS;
	INSERT INTO done_stubs
	SELECT st.stub_marks
		FROM ogr_summary su, ogr_stubs st
		WHERE su.stub_id = st.stub_id
		AND max_client >= 8014
		AND participants >= 2
		AND su.project_id = $PROJECTID
	;
	\COPY done_stubs TO '$OUTFILE' 
EOF
gzip -9 $OUTFILE &
COPYFILES="$COPYFILES $OUTFILE.gz"
done

#scp $COPYFILES remotemachine:/tmp
