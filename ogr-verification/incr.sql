-- $Id: incr.sql,v 1.3 2003/08/01 15:50:53 nerf Exp $ --
----------------
-- day_results and retire_today will probably be handled somewhere else
-- in the future, but it's here for not to facilitate testing
select now();

CREATE TEMP TABLE day_results (
	id INT,
	stub_id INTEGER,
	nodecount BIGINT,
	platform_id INT,
	return_count INT,
	in_results bool DEFAULT false NOT NULL
) WITHOUT OIDS;

analyze logadata;

-- aggregate and normalize data
INSERT INTO day_results
SELECT I.id, S.stub_id, L.nodecount, P.platform_id, sum(rowcount)
	FROM (
		SELECT lower(email) AS email, stub_marks, nodecount, 
		os_type, cpu_type, version, count(*) AS rowcount
		FROM logdata
		GROUP BY 
		lower(email), stub_marks, nodecount, os_type, cpu_type, version)
		L,
	OGR_idlookup I, OGR_stubs S, platform P
	WHERE 
		L.email = lower(I.email)
		AND L.stub_marks = S.stub_marks
		AND L.os_type = P.os_type
		AND L.cpu_type = P.cpu_type
		AND L.version = P.version
	GROUP BY
		I.id, S.stub_id, L.nodecount, P.platform_id;

CREATE UNIQUE INDEX dayresults_all ON day_results
	(id,stub_id,nodecount,platform_id);

CREATE unique INDEX dayresults_all_count ON day_results
	(id,stub_id,nodecount,platform_id,return_count) ;


select now();
----------------

CREATE TEMP TABLE retire_today (
email VARCHAR (64) NOT NULL,
id INTEGER NOT NULL,
stats_id INTEGER NOT NULL
) WITHOUT OIDS;

INSERT INTO retire_today
	SELECT email,
		id,
		(stats_id*(sign(stats_id))+id*(1-sign(stats_id)))
			AS stats_id
	FROM ogr_idlookup
	WHERE retire_date >= '20030701';

select now();
----------------
select * from retire_today;

CREATE TEMP TABLE retired_stub_id (
stub_id integer NOT NULL,
nodecount bigint NOT NULL,
id integer NOT NULL
) WITHOUT OIDS;

--ANALYZE OGR_results;
ANALYZE retire_today;

SET enable_seqscan = false;
explain analyze
INSERT INTO retired_stub_id
    SELECT DISTINCT stub_id, nodecount, id
        -- Get list of all work done by everyone who's retiring, along with their stats_id
        -- Doing this as a subquery is faster because it limits the amount of processing the main query
        -- has to do.
        FROM (SELECT DISTINCT stub_id, nodecount, rslt.id, rt.stats_id
                    FROM OGR_results rslt, retire_today rt
                    WHERE rslt.id = rt.id
                ) AS w
        -- In the final list we only want work that would duplicate other work by this participant
        -- This means we just have to see if there's any results for each stub/nodecount that were done
        -- by anyone in the retire-chain *except for the id that's newly retired*
        WHERE EXISTS (SELECT 1
                                FROM ogr_results r, ogr_idlookup l
                                WHERE r.id = l.id
                                    AND r.stub_id = w.stub_id
                                    AND r.nodecount = w.nodecount
                                    AND l.stats_id = w.stats_id
                                    AND l.id != w.id
                            )
;
SET enable_seqscan = true;

select now();
select * from retired_stub_id;

analyze retired_stub_id;

select now();

-- reduce the number of participants for a given stub, but only if what
-- we previous thought was two different people are now (because of retires)
-- seen as a single person
explain UPDATE ogr_summary
SET participants = participants - duplicated_ids
FROM (SELECT stub_id, nodecount, count(*) AS duplicated_ids
	FROM retired_stub_id GROUP BY stub_id, nodecount) dw
WHERE ogr_summary.stub_id = dw.stub_id
AND ogr_summary.nodecount = dw.nodecount;

CREATE TEMP TABLE retired_new_info (
stub_id integer NOT NULL,
nodecount bigint NOT NULL,
ids integer NOT NULL
);

explain analyze INSERT INTO retired_new_info
SELECT r.stub_id, r.nodecount
        , (SELECT count(*)
                FROM retired_stub_id rsi
                WHERE rsi.stub_id = r.stub_id
                    AND rsi.nodecount = r.nodecount
            ) AS ids
    FROM ogr_results r
        , (SELECT DISTINCT stub_id, nodecount FROM retired_stub_id) rs
    WHERE r.stub_id = rs.stub_id
        AND r.nodecount = rs.nodecount
        AND r.id NOT IN (SELECT id
                                FROM retired_stub_id rsi
                                WHERE rsi.stub_id = r.stub_id
                                    AND rsi.nodecount = r.nodecount
                            )
;
select now();
select * from retired_new_info;

analyze retired_new_info;

select now();
explain UPDATE OGR_summary
    SET participants = participants - n.ids
    FROM retired_new_info n
    WHERE OGR_summary.stub_id = n.stub_id
    AND OGR_summary.nodecount = n.nodecount
;
select now();

analyze day_results;
select now();

create temp table day_summary (
 stub_id       integer  NOT NULL,
 nodecount     bigint   NOT NULL,
 ids  integer  NOT NULL,
 max_version    integer  NOT NULL,
 in_ogr_summary boolean NOT NULL DEFAULT FALSE
) WITHOUT OIDS;

explain analyze INSERT INTO day_summary (stub_id,nodecount,ids,max_version)
SELECT stub_id, nodecount, count(DISTINCT l.stats_id) AS ids,
	max(p.version) AS max_version
    FROM day_results dr, OGR_idlookup l, platform p
    WHERE l.id = dr.id
        AND p.platform_id = dr.platform_id
AND NOT EXISTS (SELECT * FROM ogr_results r WHERE r.stub_id = dr.stub_id AND r.nodecount = dr.nodecount AND r.id = dr.id)
    GROUP BY stub_id, nodecount
;
select now();
create index day_stubnode on day_summary (stub_id,nodecount);

analyze day_summary;
select now();

-- Mark all the records that are currently in ogr_summary
-- Since we're going to update the ones that are there, then insert the
-- ones that are not, this saves us having to do the same EXISTS
-- statement twice
explain analyze UPDATE day_summary
SET in_ogr_summary = true
WHERE exists
(SELECT * FROM OGR_summary WHERE OGR_summary.stub_id = day_summary.stub_id
        AND OGR_summary.nodecount = day_summary.nodecount
        );

-- If it's threre already, update it
explain UPDATE OGR_summary
    SET participants = participants + ids
        , max_client = max(max_client, max_version)
    FROM day_summary ds
    WHERE ds.in_ogr_summary 
    AND ds.stub_id = OGR_summary.stub_id
    AND ds.nodecount = OGR_summary.nodecount
;

-- If it's not there, add it
-- Note that most of the stubs will fall under this category
explain INSERT INTO OGR_summary(stub_id, nodecount, participants, max_client)
    SELECT stub_id, nodecount, ids, max_version
    FROM day_summary ds
    WHERE NOT ds.in_ogr_summary
;

select now();
select 'All done!';
