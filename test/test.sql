--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: enriched_task; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE enriched_task AS (
        _id integer,
        _rev integer,
        summary character varying(64),
        description text,
        color character varying(8),
        priority integer,
        story_id integer,
        r_t_dates date[],
        r_t_days real[],
        t_s_dates date[],
        t_s_days real[]
);

--
-- Name: enrich_task(integer); Type: FUNCTION; Schema: public; Owner: mkulke
--

CREATE FUNCTION enrich_task(id integer) RETURNS enriched_task
    LANGUAGE plpgsql
    AS $_$
DECLARE
  ret enriched_task;
BEGIN
SELECT t.*, ARRAY_AGG(r_t.date) AS r_t_dates, ARRAY_AGG(r_t.days) AS r_t_days, ARRAY_AGG(t_s.date) AS t_s_dates, ARRAY_AGG(t_s.days) AS t_s_days FROM tasks AS t  LEFT OUTER JOIN remaining_times as r_t ON (r_t.task_id=t._id) LEFT OUTER JOIN times_spent AS t_s ON (t_s.task_id=t._id) WHERE t._id=$1 GROUP BY t._id INTO ret;
RETURN ret;
END;$_$;

--
-- Name: inc_rev(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION inc_rev() RETURNS trigger
    LANGUAGE plpgsql
    AS $$              DECLARE tid integer;
BEGIN
IF (TG_OP='INSERT') THEN tid=NEW.task_id; ELSE tid=OLD.task_id; END IF;
UPDATE tasks SET _rev=_rev+1 WHERE _id=tid;
RETURN NEW;
END;
$$;

--
-- Name: upsert_rt(key date, data real, tid integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION upsert_rt(key date, data real, t_id integer, t_rev integer) RETURNS enriched_task
    LANGUAGE plpgsql
    AS $$
DECLARE
    ret enriched_task;
BEGIN
    PERFORM * FROM tasks WHERE _id = t_id AND _rev = t_rev;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'task with id % and rev % not found', t_id, t_rev;
    END IF;
    LOOP
        UPDATE remaining_times SET days = data WHERE date = key AND task_id = t_id;
        IF found THEN
            SELECT * FROM enrich_task(t_id) INTO ret;
            RETURN ret;
        END IF;
        BEGIN
            INSERT INTO remaining_times(date, days, task_id) VALUES (key, data, t_id);
            SELECT * FROM enrich_task(t_id) INTO ret;
            RETURN ret;
        EXCEPTION WHEN unique_violation THEN
        END;
    END LOOP;
END;
$$;

--
-- Name: upsert_ts(key date, data real, tid integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION upsert_ts(key date, data real, t_id integer, t_rev integer) RETURNS enriched_task
    LANGUAGE plpgsql
    AS $$
DECLARE
    ret enriched_task;
BEGIN
    PERFORM * FROM tasks WHERE _id = t_id AND _rev = t_rev;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'task with id % and rev % not found', t_id, t_rev;
    END IF;
    LOOP
        UPDATE times_spent SET days = data WHERE date = key AND task_id = t_id;
        IF found THEN
            SELECT * FROM enrich_task(t_id) INTO ret;
            RETURN ret;
        END IF;
        BEGIN
            INSERT INTO times_spent(date, days, task_id) VALUES (key, data, t_id);
            SELECT * FROM enrich_task(t_id) INTO ret;
            RETURN ret;
        EXCEPTION WHEN unique_violation THEN
        END;
    END LOOP;
END;
$$;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: remaining_times; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE remaining_times (
    _id bigint NOT NULL,
    date date NOT NULL,
    days real NOT NULL,
    task_id integer NOT NULL
);


--
-- Name: remaining_times__id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE remaining_times__id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: remaining_times__id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE remaining_times__id_seq OWNED BY remaining_times._id;


--
-- Name: sprints; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE sprints (
    _id bigint NOT NULL,
    _rev integer DEFAULT 1 NOT NULL,
    title character varying(64) NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    color character varying(8) NOT NULL,
    start date NOT NULL,
    length integer NOT NULL
);


--
-- Name: sprints__id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sprints__id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sprints__id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE sprints__id_seq OWNED BY sprints._id;


--
-- Name: stories; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE stories (
    _id bigint NOT NULL,
    _rev integer DEFAULT 1 NOT NULL,
    title character varying(64) NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    color character varying(8) NOT NULL,
    estimation integer NOT NULL,
    priority integer NOT NULL,
    sprint_id integer NOT NULL
);


--
-- Name: stories__id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stories__id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stories__id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stories__id_seq OWNED BY stories._id;


--
-- Name: stories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE tasks (
    _id bigint NOT NULL,
    _rev integer DEFAULT 1 NOT NULL,
    summary character varying(64) NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    color character varying(8) NOT NULL,
    priority integer NOT NULL,
    story_id integer NOT NULL
);


--
-- Name: tasks__id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tasks__id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks__id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tasks__id_seq OWNED BY tasks._id;


--
-- Name: times_spent; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE times_spent (
    _id bigint NOT NULL,
    date date NOT NULL,
    days real NOT NULL,
    task_id integer NOT NULL
);


--
-- Name: times_spent__id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE times_spent__id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: times_spent__id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE times_spent__id_seq OWNED BY times_spent._id;


--
-- Name: _id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY remaining_times ALTER COLUMN _id SET DEFAULT nextval('remaining_times__id_seq'::regclass);


--
-- Name: _id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sprints ALTER COLUMN _id SET DEFAULT nextval('sprints__id_seq'::regclass);


--
-- Name: _id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY stories ALTER COLUMN _id SET DEFAULT nextval('stories__id_seq'::regclass);


--
-- Name: _id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY tasks ALTER COLUMN _id SET DEFAULT nextval('tasks__id_seq'::regclass);


--
-- Name: _id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY times_spent ALTER COLUMN _id SET DEFAULT nextval('times_spent__id_seq'::regclass);


--
-- Data for Name: remaining_times; Type: TABLE DATA; Schema: public; Owner: -
--

COPY remaining_times (_id, date, days, task_id) FROM stdin;
\.


--
-- Name: remaining_times__id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('remaining_times__id_seq', 1, false);


--
-- Data for Name: sprints; Type: TABLE DATA; Schema: public; Owner: -
--

COPY sprints (_id, _rev, title, description, color, start, length) FROM stdin;
\.


--
-- Name: sprints__id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('sprints__id_seq', 2, true);


--
-- Data for Name: stories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY stories (_id, _rev, title, description, color, estimation, priority, sprint_id) FROM stdin;
\.


--
-- Name: stories__id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('stories__id_seq', 1, false);


--
-- Name: stories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('stories_id_seq', 2, true);


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY tasks (_id, _rev, summary, description, color, priority, story_id) FROM stdin;
\.


--
-- Name: tasks__id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('tasks__id_seq', 1, false);


--
-- Data for Name: times_spent; Type: TABLE DATA; Schema: public; Owner: -
--

COPY times_spent (_id, date, days, task_id) FROM stdin;
\.


--
-- Name: times_spent__id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('times_spent__id_seq', 2, true);


--
-- Name: remaining_times_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY remaining_times
    ADD CONSTRAINT remaining_times_pkey PRIMARY KEY (_id);


--
-- Name: remaining_times_task_id_date_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY remaining_times
    ADD CONSTRAINT remaining_times_task_id_date_key UNIQUE (task_id, date);


--
-- Name: sprints_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY sprints
    ADD CONSTRAINT sprints_pkey PRIMARY KEY (_id);


--
-- Name: stories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY stories
    ADD CONSTRAINT stories_pkey PRIMARY KEY (_id);


--
-- Name: stories_sprint_id_priority_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY stories
    ADD CONSTRAINT stories_sprint_id_priority_key UNIQUE (sprint_id, priority);


--
-- Name: tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (_id);


--
-- Name: tasks_story_id_priority_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT tasks_story_id_priority_key UNIQUE (story_id, priority);


--
-- Name: times_spent_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY times_spent
    ADD CONSTRAINT times_spent_pkey PRIMARY KEY (_id);


--
-- Name: times_spent_task_id_date_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY times_spent
    ADD CONSTRAINT times_spent_task_id_date_key UNIQUE (task_id, date);


--
-- Name: inc_rev; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER inc_rev AFTER INSERT OR DELETE OR UPDATE ON remaining_times FOR EACH ROW EXECUTE PROCEDURE inc_rev();


--
-- Name: inc_rev; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER inc_rev AFTER INSERT OR DELETE OR UPDATE ON times_spent FOR EACH ROW EXECUTE PROCEDURE inc_rev();


--
-- Name: remaining_times_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY remaining_times
    ADD CONSTRAINT remaining_times_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks(_id) ON DELETE CASCADE;


--
-- Name: stories_sprint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stories
    ADD CONSTRAINT stories_sprint_id_fkey FOREIGN KEY (sprint_id) REFERENCES sprints(_id) ON DELETE CASCADE;


--
-- Name: tasks_story_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT tasks_story_id_fkey FOREIGN KEY (story_id) REFERENCES stories(_id) ON DELETE CASCADE;


--
-- Name: times_spent_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY times_spent
    ADD CONSTRAINT times_spent_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks(_id) ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: -
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM mkulke;
GRANT ALL ON SCHEMA public TO mkulke;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

