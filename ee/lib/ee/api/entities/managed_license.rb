# frozen_string_literal: true

module EE
  module API
    module Entities
      class ManagedLicense < Grape::Entity
        expose :id, :name
        expose :approval_status
      end
    end
  end
end
