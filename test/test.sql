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
UPDATE tasks SET rev=rev+1 WHERE id=NEW.task_id;
RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: remaining_times; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE remaining_times (
    id bigint NOT NULL,
    date date NOT NULL,
    days integer NOT NULL,
    task_id integer NOT NULL
);


--
-- Name: remaining_times_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE remaining_times_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: remaining_times_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE remaining_times_id_seq OWNED BY remaining_times.id;


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
    title character varying(64),
    description text DEFAULT ''::text NOT NULL,
    color character varying(8) NOT NULL,
    estimation integer NOT NULL,
    priority integer NOT NULL,
    sprint_id integer NOT NULL
);


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
-- Name: stories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stories_id_seq OWNED BY stories.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tasks (
    _id bigint NOT NULL,
    _rev integer DEFAULT 1 NOT NULL,
    summary character varying(64) NOT NULL,
    description text default '' NOT NULL,
    color character varying(8) NOT NULL,
    priority integer NOT NULL,
    story_id integer NOT NULL
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tasks_id_seq OWNED BY tasks._id;


--
-- Name: times_spent; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE times_spent (
    id bigint NOT NULL,
    date date NOT NULL,
    days integer NOT NULL,
    task_id integer NOT NULL
);


--
-- Name: times_spent_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE times_spent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: times_spent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE times_spent_id_seq OWNED BY times_spent.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY remaining_times ALTER COLUMN id SET DEFAULT nextval('remaining_times_id_seq'::regclass);


--
-- Name: _id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sprints ALTER COLUMN _id SET DEFAULT nextval('sprints__id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY stories ALTER COLUMN _id SET DEFAULT nextval('stories_id_seq'::regclass);


--
-- Name: rev; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY stories ALTER COLUMN _rev SET DEFAULT nextval('stories_rev_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY tasks ALTER COLUMN id SET DEFAULT nextval('tasks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY times_spent ALTER COLUMN id SET DEFAULT nextval('times_spent_id_seq'::regclass);


--
-- Data for Name: remaining_times; Type: TABLE DATA; Schema: public; Owner: -
--

COPY remaining_times (id, date, days, task_id) FROM stdin;
\.


--
-- Name: remaining_times_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('remaining_times_id_seq', 1, false);


--
-- Name: sprints__id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('sprints__id_seq', 2, true);


--
-- Name: stories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('stories_id_seq', 2, true);


--
-- Name: stories_rev_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('stories_rev_seq', 2, true);

--
-- Name: tasks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('tasks_id_seq', 1, true);


--
-- Data for Name: times_spent; Type: TABLE DATA; Schema: public; Owner: -
--

COPY times_spent (id, date, days, task_id) FROM stdin;
2	2013-01-01	2	1
\.


--
-- Name: times_spent_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('times_spent_id_seq', 2, true);


--
-- Name: remaining_times_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY remaining_times
    ADD CONSTRAINT remaining_times_pkey PRIMARY KEY (id);


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
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: tasks_story_id_priority_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tasks
    ADD CONSTRAINT tasks_story_id_priority_key UNIQUE (story_id, priority);


--
-- Name: times_spent_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY times_spent
    ADD CONSTRAINT times_spent_pkey PRIMARY KEY (id);


--
-- Name: times_spent_task_id_date_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY times_spent
    ADD CONSTRAINT times_spent_task_id_date_key UNIQUE (task_id, date);


--
-- Name: inc_rev; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER inc_rev AFTER INSERT OR DELETE OR UPDATE ON times_spent FOR EACH ROW EXECUTE PROCEDURE inc_rev();


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

