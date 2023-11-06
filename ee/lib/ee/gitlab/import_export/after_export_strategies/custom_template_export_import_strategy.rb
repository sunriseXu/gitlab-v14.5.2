# frozen_string_literal: true

module EE
  module Gitlab
    module ImportExport
      module AfterExportStrategies
        class CustomTemplateExportImportStrategy < ::Gitlab::ImportExport::AfterExportStrategies::BaseAfterExportStrategy
          include ::Gitlab::Utils::StrongMemoize
          include ::Gitlab::TemplateHelper

          validates :export_into_project_id, presence: true

          attr_reader :params

          def initialize(export_into_project_id:)
            super

            @params = {}
          end

          protected

          def strategy_execute
            return unless export_into_project_exists?

            prepare_template_environment(export_file)

            set_import_attributes

            ::RepositoryImportWorker.new.perform(export_into_project_id)
          ensure
            export_file.close if export_file.respond_to?(:close)
          end

          def export_file
            strong_memoize(:export_file) do
              project.export_file&.file
            end
          end

          def set_import_attributes
            ::Project.update(export_into_project_id, params)
          end

          # rubocop: disable CodeReuse/ActiveRecord
          def export_into_project_exists?
            ::Project.exists?(export_into_project_id)
          end
          # rubocop: enable CodeReuse/ActiveRecord
        end
      end
    end
  end
end
