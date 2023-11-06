# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::MergeRequestDiffRegistriesResolver do
  it_behaves_like 'a Geo registries resolver', :geo_merge_request_diff_registry
end
