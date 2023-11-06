# frozen_string_literal: true

module Mutations
  module IncidentManagement
    module OncallSchedule
      class Create < OncallScheduleBase
        include FindsProject

        graphql_name 'OncallScheduleCreate'

        argument :project_path, GraphQL::Types::ID,
                 required: true,
                 description: 'Project to create the on-call schedule in.'

        argument :name, GraphQL::Types::String,
                 required: true,
                 description: 'Name of the on-call schedule.'

        argument :description, GraphQL::Types::String,
                 required: false,
                 description: 'Description of the on-call schedule.'

        argument :timezone, GraphQL::Types::String,
                 required: true,
                 description: 'Timezone of the on-call schedule.'

        def resolve(args)
          project = authorized_find!(args[:project_path])

          response ::IncidentManagement::OncallSchedules::CreateService.new(
            project,
            current_user,
            args.slice(:name, :description, :timezone)
          ).execute
        end
      end
    end
  end
end
