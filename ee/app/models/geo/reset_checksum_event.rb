# frozen_string_literal: true

module Geo
  class ResetChecksumEvent < ApplicationRecord
    include Geo::Model
    include Geo::Eventable

    belongs_to :project

    validates :project, presence: true
  end
end
