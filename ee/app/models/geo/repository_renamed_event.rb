# frozen_string_literal: true

module Geo
  class RepositoryRenamedEvent < ApplicationRecord
    include Geo::Model
    include Geo::Eventable

    belongs_to :project

    validates :project, :repository_storage_name, :old_path_with_namespace,
      :new_path_with_namespace, :old_wiki_path_with_namespace,
      :new_wiki_path_with_namespace,
      :old_path, :new_path, presence: true
  end
end
