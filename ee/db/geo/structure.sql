CREATE TABLE ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

CREATE TABLE container_repository_registry (
    id integer NOT NULL,
    container_repository_id integer NOT NULL,
    state character varying,
    retry_count integer DEFAULT 0,
    last_sync_failure character varying,
    retry_at timestamp without time zone,
    last_synced_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL
);

CREATE SEQUENCE container_repository_registry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE container_repository_registry_id_seq OWNED BY container_repository_registry.id;

CREATE TABLE design_registry (
    id integer NOT NULL,
    project_id integer NOT NULL,
    state character varying(20),
    retry_count integer DEFAULT 0,
    last_sync_failure character varying,
    force_to_redownload boolean,
    missing_on_primary boolean,
    retry_at timestamp without time zone,
    last_synced_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL
);

CREATE SEQUENCE design_registry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE design_registry_id_seq OWNED BY design_registry.id;

CREATE TABLE event_log_states (
    event_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);

CREATE SEQUENCE event_log_states_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE event_log_states_event_id_seq OWNED BY event_log_states.event_id;

CREATE TABLE file_registry (
    id integer NOT NULL,
    file_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    retry_count integer DEFAULT 0,
    retry_at timestamp without time zone,
    missing_on_primary boolean DEFAULT false NOT NULL,
    state smallint DEFAULT 0 NOT NULL,
    last_synced_at timestamp with time zone,
    last_sync_failure character varying(255)
);

CREATE SEQUENCE file_registry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE file_registry_id_seq OWNED BY file_registry.id;

CREATE TABLE group_wiki_repository_registry (
    id bigint NOT NULL,
    retry_at timestamp with time zone,
    last_synced_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    group_wiki_repository_id bigint NOT NULL,
    state smallint DEFAULT 0 NOT NULL,
    retry_count smallint DEFAULT 0,
    last_sync_failure text,
    force_to_redownload boolean,
    missing_on_primary boolean
);

CREATE SEQUENCE group_wiki_repository_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE group_wiki_repository_registry_id_seq OWNED BY group_wiki_repository_registry.id;

CREATE TABLE job_artifact_registry (
    id integer NOT NULL,
    created_at timestamp with time zone,
    retry_at timestamp with time zone,
    bytes bigint,
    artifact_id integer,
    retry_count integer,
    success boolean,
    sha256 character varying,
    missing_on_primary boolean DEFAULT false NOT NULL
);

CREATE SEQUENCE job_artifact_registry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE job_artifact_registry_id_seq OWNED BY job_artifact_registry.id;

CREATE TABLE lfs_object_registry (
    id bigint NOT NULL,
    created_at timestamp with time zone,
    retry_at timestamp with time zone,
    bytes bigint,
    lfs_object_id integer,
    retry_count integer DEFAULT 0,
    missing_on_primary boolean DEFAULT false NOT NULL,
    success boolean DEFAULT false NOT NULL,
    sha256 bytea,
    state smallint DEFAULT 0 NOT NULL,
    last_synced_at timestamp with time zone,
    last_sync_failure text
);

CREATE SEQUENCE lfs_object_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE lfs_object_registry_id_seq OWNED BY lfs_object_registry.id;

CREATE TABLE merge_request_diff_registry (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    retry_at timestamp with time zone,
    last_synced_at timestamp with time zone,
    merge_request_diff_id bigint NOT NULL,
    state smallint DEFAULT 0 NOT NULL,
    retry_count smallint DEFAULT 0,
    last_sync_failure text,
    verification_started_at timestamp with time zone,
    verified_at timestamp with time zone,
    verification_retry_at timestamp with time zone,
    verification_retry_count integer,
    verification_state smallint DEFAULT 0 NOT NULL,
    checksum_mismatch boolean,
    verification_checksum bytea,
    verification_checksum_mismatched bytea,
    verification_failure character varying(255)
);

CREATE SEQUENCE merge_request_diff_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE merge_request_diff_registry_id_seq OWNED BY merge_request_diff_registry.id;

CREATE TABLE package_file_registry (
    id integer NOT NULL,
    package_file_id integer NOT NULL,
    state integer DEFAULT 0 NOT NULL,
    retry_count integer DEFAULT 0,
    last_sync_failure character varying(255),
    retry_at timestamp with time zone,
    last_synced_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    verification_failure character varying(255),
    verification_checksum bytea,
    checksum_mismatch boolean,
    verification_checksum_mismatched bytea,
    verification_retry_count integer,
    verified_at timestamp with time zone,
    verification_retry_at timestamp with time zone,
    verification_state smallint DEFAULT 0 NOT NULL,
    verification_started_at timestamp with time zone
);

CREATE SEQUENCE package_file_registry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE package_file_registry_id_seq OWNED BY package_file_registry.id;

CREATE TABLE pages_deployment_registry (
    id bigint NOT NULL,
    pages_deployment_id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    last_synced_at timestamp with time zone,
    retry_at timestamp with time zone,
    state smallint DEFAULT 0 NOT NULL,
    retry_count smallint DEFAULT 0 NOT NULL,
    last_sync_failure character varying(255)
);

CREATE SEQUENCE pages_deployment_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE pages_deployment_registry_id_seq OWNED BY pages_deployment_registry.id;

CREATE TABLE pipeline_artifact_registry (
    id bigint NOT NULL,
    pipeline_artifact_id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    last_synced_at timestamp with time zone,
    retry_at timestamp with time zone,
    verified_at timestamp with time zone,
    verification_started_at timestamp with time zone,
    verification_retry_at timestamp with time zone,
    state smallint DEFAULT 0 NOT NULL,
    verification_state smallint DEFAULT 0 NOT NULL,
    retry_count smallint DEFAULT 0,
    verification_retry_count smallint DEFAULT 0,
    checksum_mismatch boolean DEFAULT false NOT NULL,
    verification_checksum bytea,
    verification_checksum_mismatched bytea,
    verification_failure character varying(255),
    last_sync_failure character varying(255)
);

CREATE SEQUENCE pipeline_artifact_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE pipeline_artifact_registry_id_seq OWNED BY pipeline_artifact_registry.id;

CREATE TABLE project_registry (
    id integer NOT NULL,
    project_id integer NOT NULL,
    last_repository_synced_at timestamp without time zone,
    last_repository_successful_sync_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    resync_repository boolean DEFAULT true NOT NULL,
    resync_wiki boolean DEFAULT true NOT NULL,
    last_wiki_synced_at timestamp without time zone,
    last_wiki_successful_sync_at timestamp without time zone,
    repository_retry_count integer,
    repository_retry_at timestamp without time zone,
    force_to_redownload_repository boolean,
    wiki_retry_count integer,
    wiki_retry_at timestamp without time zone,
    force_to_redownload_wiki boolean,
    last_repository_sync_failure character varying,
    last_wiki_sync_failure character varying,
    last_repository_verification_failure character varying,
    last_wiki_verification_failure character varying,
    repository_verification_checksum_sha bytea,
    wiki_verification_checksum_sha bytea,
    repository_checksum_mismatch boolean DEFAULT false NOT NULL,
    wiki_checksum_mismatch boolean DEFAULT false NOT NULL,
    last_repository_check_failed boolean,
    last_repository_check_at timestamp with time zone,
    resync_repository_was_scheduled_at timestamp with time zone,
    resync_wiki_was_scheduled_at timestamp with time zone,
    repository_missing_on_primary boolean,
    wiki_missing_on_primary boolean,
    repository_verification_retry_count integer,
    wiki_verification_retry_count integer,
    last_repository_verification_ran_at timestamp with time zone,
    last_wiki_verification_ran_at timestamp with time zone,
    repository_verification_checksum_mismatched bytea,
    wiki_verification_checksum_mismatched bytea,
    primary_repository_checksummed boolean DEFAULT false NOT NULL,
    primary_wiki_checksummed boolean DEFAULT false NOT NULL
);

CREATE SEQUENCE project_registry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE project_registry_id_seq OWNED BY project_registry.id;

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);

CREATE TABLE secondary_usage_data (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE SEQUENCE secondary_usage_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE secondary_usage_data_id_seq OWNED BY secondary_usage_data.id;

CREATE TABLE snippet_repository_registry (
    id bigint NOT NULL,
    retry_at timestamp with time zone,
    last_synced_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    snippet_repository_id bigint NOT NULL,
    state smallint DEFAULT 0 NOT NULL,
    retry_count smallint DEFAULT 0,
    last_sync_failure text,
    force_to_redownload boolean,
    missing_on_primary boolean,
    verification_started_at timestamp with time zone,
    verified_at timestamp with time zone,
    verification_retry_at timestamp with time zone,
    verification_retry_count integer,
    verification_state smallint DEFAULT 0 NOT NULL,
    checksum_mismatch boolean,
    verification_checksum bytea,
    verification_checksum_mismatched bytea,
    verification_failure character varying(255)
);

CREATE SEQUENCE snippet_repository_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE snippet_repository_registry_id_seq OWNED BY snippet_repository_registry.id;

CREATE TABLE terraform_state_version_registry (
    id bigint NOT NULL,
    terraform_state_version_id bigint NOT NULL,
    state smallint DEFAULT 0 NOT NULL,
    retry_count smallint DEFAULT 0 NOT NULL,
    retry_at timestamp with time zone,
    last_synced_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    last_sync_failure text,
    verification_started_at timestamp with time zone,
    verified_at timestamp with time zone,
    verification_retry_at timestamp with time zone,
    verification_retry_count integer DEFAULT 0,
    verification_state smallint DEFAULT 0 NOT NULL,
    checksum_mismatch boolean DEFAULT false NOT NULL,
    verification_checksum bytea,
    verification_checksum_mismatched bytea,
    verification_failure character varying(255)
);

CREATE SEQUENCE terraform_state_version_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE terraform_state_version_registry_id_seq OWNED BY terraform_state_version_registry.id;

ALTER TABLE ONLY container_repository_registry ALTER COLUMN id SET DEFAULT nextval('container_repository_registry_id_seq'::regclass);

ALTER TABLE ONLY design_registry ALTER COLUMN id SET DEFAULT nextval('design_registry_id_seq'::regclass);

ALTER TABLE ONLY event_log_states ALTER COLUMN event_id SET DEFAULT nextval('event_log_states_event_id_seq'::regclass);

ALTER TABLE ONLY file_registry ALTER COLUMN id SET DEFAULT nextval('file_registry_id_seq'::regclass);

ALTER TABLE ONLY group_wiki_repository_registry ALTER COLUMN id SET DEFAULT nextval('group_wiki_repository_registry_id_seq'::regclass);

ALTER TABLE ONLY job_artifact_registry ALTER COLUMN id SET DEFAULT nextval('job_artifact_registry_id_seq'::regclass);

ALTER TABLE ONLY lfs_object_registry ALTER COLUMN id SET DEFAULT nextval('lfs_object_registry_id_seq'::regclass);

ALTER TABLE ONLY merge_request_diff_registry ALTER COLUMN id SET DEFAULT nextval('merge_request_diff_registry_id_seq'::regclass);

ALTER TABLE ONLY package_file_registry ALTER COLUMN id SET DEFAULT nextval('package_file_registry_id_seq'::regclass);

ALTER TABLE ONLY pages_deployment_registry ALTER COLUMN id SET DEFAULT nextval('pages_deployment_registry_id_seq'::regclass);

ALTER TABLE ONLY pipeline_artifact_registry ALTER COLUMN id SET DEFAULT nextval('pipeline_artifact_registry_id_seq'::regclass);

ALTER TABLE ONLY project_registry ALTER COLUMN id SET DEFAULT nextval('project_registry_id_seq'::regclass);

ALTER TABLE ONLY secondary_usage_data ALTER COLUMN id SET DEFAULT nextval('secondary_usage_data_id_seq'::regclass);

ALTER TABLE ONLY snippet_repository_registry ALTER COLUMN id SET DEFAULT nextval('snippet_repository_registry_id_seq'::regclass);

ALTER TABLE ONLY terraform_state_version_registry ALTER COLUMN id SET DEFAULT nextval('terraform_state_version_registry_id_seq'::regclass);

ALTER TABLE ONLY ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);

ALTER TABLE ONLY container_repository_registry
    ADD CONSTRAINT container_repository_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY design_registry
    ADD CONSTRAINT design_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY event_log_states
    ADD CONSTRAINT event_log_states_pkey PRIMARY KEY (event_id);

ALTER TABLE ONLY file_registry
    ADD CONSTRAINT file_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY group_wiki_repository_registry
    ADD CONSTRAINT group_wiki_repository_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY job_artifact_registry
    ADD CONSTRAINT job_artifact_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY lfs_object_registry
    ADD CONSTRAINT lfs_object_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY merge_request_diff_registry
    ADD CONSTRAINT merge_request_diff_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY package_file_registry
    ADD CONSTRAINT package_file_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY pages_deployment_registry
    ADD CONSTRAINT pages_deployment_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY pipeline_artifact_registry
    ADD CONSTRAINT pipeline_artifact_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY project_registry
    ADD CONSTRAINT project_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);

ALTER TABLE ONLY secondary_usage_data
    ADD CONSTRAINT secondary_usage_data_pkey PRIMARY KEY (id);

ALTER TABLE ONLY snippet_repository_registry
    ADD CONSTRAINT snippet_repository_registry_pkey PRIMARY KEY (id);

ALTER TABLE ONLY terraform_state_version_registry
    ADD CONSTRAINT terraform_state_version_registry_pkey PRIMARY KEY (id);

CREATE INDEX idx_project_registry_failed_repositories_partial ON project_registry USING btree (repository_retry_count) WHERE ((repository_retry_count > 0) OR (last_repository_verification_failure IS NOT NULL) OR repository_checksum_mismatch);

CREATE INDEX idx_project_registry_on_repo_checksums_and_failure_partial ON project_registry USING btree (project_id) WHERE ((repository_verification_checksum_sha IS NULL) AND (last_repository_verification_failure IS NULL));

CREATE INDEX idx_project_registry_on_repository_checksum_sha_partial ON project_registry USING btree (repository_verification_checksum_sha) WHERE (repository_verification_checksum_sha IS NULL);

CREATE INDEX idx_project_registry_on_repository_failure_partial ON project_registry USING btree (project_id) WHERE (last_repository_verification_failure IS NOT NULL);

CREATE INDEX idx_project_registry_on_wiki_checksum_sha_partial ON project_registry USING btree (wiki_verification_checksum_sha) WHERE (wiki_verification_checksum_sha IS NULL);

CREATE INDEX idx_project_registry_on_wiki_checksums_and_failure_partial ON project_registry USING btree (project_id) WHERE ((wiki_verification_checksum_sha IS NULL) AND (last_wiki_verification_failure IS NULL));

CREATE INDEX idx_project_registry_on_wiki_failure_partial ON project_registry USING btree (project_id) WHERE (last_wiki_verification_failure IS NOT NULL);

CREATE INDEX idx_project_registry_pending_repositories_partial ON project_registry USING btree (repository_retry_count) WHERE ((repository_retry_count IS NULL) AND (last_repository_successful_sync_at IS NOT NULL) AND ((resync_repository = true) OR ((repository_verification_checksum_sha IS NULL) AND (last_repository_verification_failure IS NULL))));

CREATE INDEX idx_project_registry_synced_repositories_partial ON project_registry USING btree (last_repository_successful_sync_at) WHERE ((resync_repository = false) AND (repository_retry_count IS NULL) AND (repository_verification_checksum_sha IS NOT NULL));

CREATE INDEX idx_repository_checksum_mismatch ON project_registry USING btree (project_id) WHERE (repository_checksum_mismatch = true);

CREATE INDEX idx_wiki_checksum_mismatch ON project_registry USING btree (project_id) WHERE (wiki_checksum_mismatch = true);

CREATE INDEX index_container_repository_registry_on_retry_at ON container_repository_registry USING btree (retry_at);

CREATE INDEX index_container_repository_registry_on_state ON container_repository_registry USING btree (state);

CREATE UNIQUE INDEX index_container_repository_registry_repository_id_unique ON container_repository_registry USING btree (container_repository_id);

CREATE UNIQUE INDEX index_design_registry_on_project_id ON design_registry USING btree (project_id);

CREATE INDEX index_design_registry_on_retry_at ON design_registry USING btree (retry_at);

CREATE INDEX index_design_registry_on_state ON design_registry USING btree (state);

CREATE INDEX index_file_registry_on_retry_at ON file_registry USING btree (retry_at);

CREATE UNIQUE INDEX index_g_wiki_repository_registry_on_group_wiki_repository_id ON group_wiki_repository_registry USING btree (group_wiki_repository_id);

CREATE INDEX index_group_wiki_repository_registry_on_retry_at ON group_wiki_repository_registry USING btree (retry_at);

CREATE INDEX index_group_wiki_repository_registry_on_state ON group_wiki_repository_registry USING btree (state);

CREATE INDEX index_job_artifact_registry_on_artifact_id ON job_artifact_registry USING btree (artifact_id);

CREATE INDEX index_job_artifact_registry_on_retry_at ON job_artifact_registry USING btree (retry_at);

CREATE INDEX index_job_artifact_registry_on_success ON job_artifact_registry USING btree (success);

CREATE UNIQUE INDEX index_lfs_object_registry_on_lfs_object_id ON lfs_object_registry USING btree (lfs_object_id);

CREATE INDEX index_lfs_object_registry_on_retry_at ON lfs_object_registry USING btree (retry_at);

CREATE INDEX index_lfs_object_registry_on_success ON lfs_object_registry USING btree (success);

CREATE UNIQUE INDEX index_merge_request_diff_registry_on_mr_diff_id ON merge_request_diff_registry USING btree (merge_request_diff_id);

CREATE INDEX index_merge_request_diff_registry_on_retry_at ON merge_request_diff_registry USING btree (retry_at);

CREATE INDEX index_merge_request_diff_registry_on_state ON merge_request_diff_registry USING btree (state);

CREATE INDEX index_package_file_registry_on_repository_id ON package_file_registry USING btree (package_file_id);

CREATE INDEX index_package_file_registry_on_retry_at ON package_file_registry USING btree (retry_at);

CREATE INDEX index_package_file_registry_on_state ON package_file_registry USING btree (state);

CREATE UNIQUE INDEX index_pages_deployment_registry_on_pages_deployment_id ON pages_deployment_registry USING btree (pages_deployment_id);

CREATE INDEX index_pages_deployment_registry_on_retry_at ON pages_deployment_registry USING btree (retry_at);

CREATE INDEX index_pages_deployment_registry_on_state ON pages_deployment_registry USING btree (state);

CREATE UNIQUE INDEX index_pipeline_artifact_registry_on_pipeline_artifact_id ON pipeline_artifact_registry USING btree (pipeline_artifact_id);

CREATE INDEX index_pipeline_artifact_registry_on_retry_at ON pipeline_artifact_registry USING btree (retry_at);

CREATE INDEX index_pipeline_artifact_registry_on_state ON pipeline_artifact_registry USING btree (state);

CREATE INDEX index_project_registry_on_last_repository_successful_sync_at ON project_registry USING btree (last_repository_successful_sync_at);

CREATE INDEX index_project_registry_on_last_repository_synced_at ON project_registry USING btree (last_repository_synced_at);

CREATE UNIQUE INDEX index_project_registry_on_project_id ON project_registry USING btree (project_id);

CREATE INDEX index_project_registry_on_repository_retry_at ON project_registry USING btree (repository_retry_at);

CREATE INDEX index_project_registry_on_resync_repository ON project_registry USING btree (resync_repository);

CREATE INDEX index_project_registry_on_resync_wiki ON project_registry USING btree (resync_wiki);

CREATE INDEX index_project_registry_on_wiki_retry_at ON project_registry USING btree (wiki_retry_at);

CREATE INDEX index_snippet_repository_registry_on_retry_at ON snippet_repository_registry USING btree (retry_at);

CREATE UNIQUE INDEX index_snippet_repository_registry_on_snippet_repository_id ON snippet_repository_registry USING btree (snippet_repository_id);

CREATE INDEX index_snippet_repository_registry_on_state ON snippet_repository_registry USING btree (state);

CREATE INDEX index_state_in_lfs_objects ON lfs_object_registry USING btree (state);

CREATE INDEX index_terraform_state_version_registry_on_retry_at ON terraform_state_version_registry USING btree (retry_at);

CREATE INDEX index_terraform_state_version_registry_on_state ON terraform_state_version_registry USING btree (state);

CREATE UNIQUE INDEX index_terraform_state_version_registry_on_t_state_version_id ON terraform_state_version_registry USING btree (terraform_state_version_id);

CREATE UNIQUE INDEX index_tf_state_versions_registry_tf_state_versions_id_unique ON terraform_state_version_registry USING btree (terraform_state_version_id);

CREATE INDEX merge_request_diff_registry_failed_verification ON merge_request_diff_registry USING btree (verification_retry_at NULLS FIRST) WHERE ((state = 2) AND (verification_state = 3));

CREATE INDEX merge_request_diff_registry_needs_verification ON merge_request_diff_registry USING btree (verification_state) WHERE ((state = 2) AND (verification_state = ANY (ARRAY[0, 3])));

CREATE INDEX merge_request_diff_registry_pending_verification ON merge_request_diff_registry USING btree (verified_at NULLS FIRST) WHERE ((state = 2) AND (verification_state = 0));

CREATE INDEX package_file_registry_failed_verification ON package_file_registry USING btree (verification_retry_at NULLS FIRST) WHERE ((state = 2) AND (verification_state = 3));

CREATE INDEX package_file_registry_needs_verification ON package_file_registry USING btree (verification_state) WHERE ((state = 2) AND (verification_state = ANY (ARRAY[0, 3])));

CREATE INDEX package_file_registry_pending_verification ON package_file_registry USING btree (verified_at NULLS FIRST) WHERE ((state = 2) AND (verification_state = 0));

CREATE INDEX pipeline_artifact_registry_failed_verification ON pipeline_artifact_registry USING btree (verification_retry_at NULLS FIRST) WHERE ((state = 2) AND (verification_state = 3));

CREATE INDEX pipeline_artifact_registry_needs_verification ON pipeline_artifact_registry USING btree (verification_state) WHERE ((state = 2) AND (verification_state = ANY (ARRAY[0, 3])));

CREATE INDEX pipeline_artifact_registry_pending_verification ON pipeline_artifact_registry USING btree (verified_at NULLS FIRST) WHERE ((state = 2) AND (verification_state = 0));

CREATE INDEX snippet_repository_registry_failed_verification ON snippet_repository_registry USING btree (verification_retry_at NULLS FIRST) WHERE ((state = 2) AND (verification_state = 3));

CREATE INDEX snippet_repository_registry_needs_verification ON snippet_repository_registry USING btree (verification_state) WHERE ((state = 2) AND (verification_state = ANY (ARRAY[0, 3])));

CREATE INDEX snippet_repository_registry_pending_verification ON snippet_repository_registry USING btree (verified_at NULLS FIRST) WHERE ((state = 2) AND (verification_state = 0));

CREATE INDEX terraform_state_version_registry_failed_verification ON terraform_state_version_registry USING btree (verification_retry_at NULLS FIRST) WHERE ((state = 2) AND (verification_state = 3));

CREATE INDEX terraform_state_version_registry_needs_verification ON terraform_state_version_registry USING btree (verification_state) WHERE ((state = 2) AND (verification_state = ANY (ARRAY[0, 3])));

CREATE INDEX terraform_state_version_registry_pending_verification ON terraform_state_version_registry USING btree (verified_at NULLS FIRST) WHERE ((state = 2) AND (verification_state = 0));
