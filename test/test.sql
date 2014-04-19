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
-- Name: inc_rev(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION inc_rev() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
UPDATE tasks SET _rev=_rev+1 WHERE _id=NEW.task_id;
RETURN NEW;
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
    days integer NOT NULL,
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
    days integer NOT NULL,
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

SELECT pg_catalog.setval('times_spent__id_seq', 1, false);


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
    ADD CONSTRAINT stories_sprint_id_fkey FOREIGN KEY (sprint_id) REFERENCES sprints(_id);


--
-- Name: tasks_story_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT tasks_story_id_fkey FOREIGN KEY (story_id) REFERENCES stories(_id);


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

