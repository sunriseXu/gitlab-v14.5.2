# frozen_string_literal: true

class Profiles::UsageQuotasController < Profiles::ApplicationController
  before_action :push_additional_repo_storage_by_namespace_feature, only: :index

  feature_category :purchase

  def index
    @namespace = current_user.namespace
    @projects = @namespace.projects.with_shared_runners.page(params[:page])
  end

  private

  def push_additional_repo_storage_by_namespace_feature
    push_to_gon_attributes(:features, :additional_repo_storage_by_namespace, current_user.namespace.additional_repo_storage_by_namespace_enabled?)
  end
end
