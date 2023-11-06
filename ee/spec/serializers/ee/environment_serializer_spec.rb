# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::EnvironmentSerializer do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :repository) }

  before_all do
    project.add_developer(user)
  end

  before do
    stub_licensed_features(environment_alerts: true)
  end

  it_behaves_like 'avoid N+1 on environments serialization'

  def create_environment_with_associations(project)
    create(:environment, project: project).tap do |environment|
      create(:deployment, :success, environment: environment, project: project)
      create(:deployment, :running, environment: environment, project: project)
      create(:protected_environment, :maintainers_can_deploy, name: environment.name, project: project)
      prometheus_alert = create(:prometheus_alert, project: project, environment: environment)
      create(:alert_management_alert, :triggered, :prometheus, project: project, environment: environment, prometheus_alert: prometheus_alert)
    end
  end
end
