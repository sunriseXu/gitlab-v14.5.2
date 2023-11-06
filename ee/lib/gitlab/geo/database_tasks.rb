# frozen_string_literal: true

module Gitlab
  module Geo
    module DatabaseTasks
      extend self

      DATABASE_CONFIG = 'config/database.yml'
      GEO_DATABASE_CONFIG = 'config/database_geo.yml'
      GEO_DB_DIR = 'ee/db/geo'

      def method_missing(method_name, *args, &block)
        with_geo_db do
          ActiveRecord::Tasks::DatabaseTasks.public_send(method_name, *args, &block) # rubocop:disable GitlabSecurity/PublicSend
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        ActiveRecord::Tasks::DatabaseTasks.respond_to?(method_name) || super
      end

      def rollback
        step = ENV['STEP'] ? ENV['STEP'].to_i : 1

        with_geo_db do
          migration_context.rollback(step)
        end
      end

      def version
        with_geo_db do
          ActiveRecord::Migrator.current_version
        end
      end

      def dump_schema_after_migration?
        with_geo_db do
          !!ActiveRecord::Base.dump_schema_after_migration
        end
      end

      def pending_migrations
        with_geo_db do
          migration_context.open.pending_migrations
        end
      end

      def migration_context
        ActiveRecord::MigrationContext.new(ActiveRecord::Migrator.migrations_paths, ActiveRecord::SchemaMigration)
      end

      def abort_if_no_geo_config!
        @geo_config_exists ||= File.exist?(Rails.root.join(GEO_DATABASE_CONFIG)) # rubocop:disable Gitlab/ModuleWithInstanceVariables

        unless @geo_config_exists # rubocop:disable Gitlab/ModuleWithInstanceVariables
          abort("Failed to open #{GEO_DATABASE_CONFIG}. Consult the documentation on how to set up GitLab Geo.")
        end
      end

      module Schema
        extend self

        def dump
          require 'active_record/schema_dumper'

          Gitlab::Geo::DatabaseTasks.with_geo_db do
            ActiveRecord::Tasks::DatabaseTasks.dump_schema(Gitlab::Geo::DatabaseTasks.db_config)
          end
        end
      end

      module Migrate
        extend self

        def up
          version = ENV['VERSION'] ? ENV['VERSION'].to_i : nil
          raise 'VERSION is required' unless version

          Gitlab::Geo::DatabaseTasks.with_geo_db do
            Gitlab::Geo::DatabaseTasks.migration_context.run(:up, version)
          end
        end

        def down
          version = ENV['VERSION'] ? ENV['VERSION'].to_i : nil
          raise 'VERSION is required - To go down one migration, run db:rollback' unless version

          Gitlab::Geo::DatabaseTasks.with_geo_db do
            Gitlab::Geo::DatabaseTasks.migration_context.run(:down, version)
          end
        end

        def status
          Gitlab::Geo::DatabaseTasks.with_geo_db do
            unless ActiveRecord::SchemaMigration.table_exists?
              abort 'Schema migrations table does not exist yet.'
            end

            db_list = ActiveRecord::SchemaMigration.normalized_versions
            file_list =
              ActiveRecord::Migrator.migrations_paths.flat_map do |path|
                # match "20091231235959_some_name.rb" and "001_some_name.rb" pattern
                Dir.foreach(path).grep(/^(\d{3,})_(.+)\.rb$/) do
                  version = ActiveRecord::SchemaMigration.normalize_migration_number(Regexp.last_match(1))
                  status = db_list.delete(version) ? 'up' : 'down'
                  [status, version, Regexp.last_match(2).humanize]
                end
              end

            db_list.map! do |version|
              ['up', version, '********** NO FILE **********']
            end
            # output
            puts "\ndatabase: #{ActiveRecord::Base.connection_db_config.database}\n\n"
            puts "#{'Status'.center(8)}  #{'Migration ID'.ljust(14)}  Migration Name"
            puts "-" * 50
            (db_list + file_list).sort_by { |_, version, _| version }.each do |status, version, name|
              puts "#{status.center(8)}  #{version.ljust(14)}  #{name}"
            end
            puts
          end
        end
      end

      module Test
        extend self

        def load
          Gitlab::Geo::DatabaseTasks.with_geo_db do
            should_reconnect = ActiveRecord::Base.connection_pool.active_connection?
            ActiveRecord::Schema.verbose = false
            ActiveRecord::Tasks::DatabaseTasks.load_schema(ActiveRecord::Base.configurations.configs_for(env_name: 'test').first, :sql, ENV['SCHEMA'])
          ensure
            if should_reconnect
              ActiveRecord::Base.establish_connection(Gitlab::Geo::DatabaseTasks.db_config)
            end
          end
        end

        def purge
          Gitlab::Geo::DatabaseTasks.with_geo_db do
            ActiveRecord::Tasks::DatabaseTasks.purge(ActiveRecord::Base.configurations.configs_for(env_name: 'test').first)
          end
        end
      end

      def geo_settings
        {
          database_config: YAML.load_file(GEO_DATABASE_CONFIG),
          db_dir: GEO_DB_DIR,
          migrations_paths: geo_migrations_paths,
          schema_migrations_path: geo_schema_migrations_path,
          seed_loader: SeedLoader.new
        }
      end

      def geo_migrations_paths
        migrations_paths = [geo_migrate_path]
        migrations_paths << geo_post_migration_path unless ENV['SKIP_POST_DEPLOYMENT_MIGRATIONS']
        migrations_paths
      end

      def geo_migrate_path
        Rails.root.join(GEO_DB_DIR, 'migrate')
      end

      def geo_post_migration_path
        Rails.root.join(GEO_DB_DIR, 'post_migrate')
      end

      def geo_schema_migrations_path
        Rails.root.join(GEO_DB_DIR, 'schema_migrations').to_s
      end

      def with_geo_db
        abort_if_no_geo_config!

        original_settings = {
          database_config: ActiveRecord::Tasks::DatabaseTasks.database_configuration&.dup || YAML.load_file(DATABASE_CONFIG),
          db_dir: ActiveRecord::Tasks::DatabaseTasks.db_dir,
          migrations_paths: ActiveRecord::Tasks::DatabaseTasks.migrations_paths,
          seed_loader: ActiveRecord::Tasks::DatabaseTasks.seed_loader,
          schema_migrations_path: Gitlab::Database::SchemaMigrations::Context.default_schema_migrations_path
        }

        set_db_env(geo_settings)

        yield
      ensure
        set_db_env(original_settings)
      end

      def db_config
        ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).first
      end

      def set_db_env(settings)
        ActiveRecord::Tasks::DatabaseTasks.database_configuration = settings[:database_config]
        ActiveRecord::Tasks::DatabaseTasks.db_dir = settings[:db_dir]
        ActiveRecord::Tasks::DatabaseTasks.migrations_paths = settings[:migrations_paths]
        ActiveRecord::Tasks::DatabaseTasks.seed_loader = settings[:seed_loader]

        ActiveRecord::Base.configurations = ActiveRecord::Tasks::DatabaseTasks.database_configuration || {}
        ActiveRecord::Migrator.migrations_paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths
        Gitlab::Database::SchemaMigrations::Context.default_schema_migrations_path = settings[:schema_migrations_path]

        ActiveRecord::Base.establish_connection(db_config)
      end

      class SeedLoader
        def load_seed
          load(File.join(GEO_DB_DIR, 'seeds.rb'))
        end
      end
    end
  end
end
