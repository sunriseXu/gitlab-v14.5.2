# frozen_string_literal: true

module Projects::OnDemandScansHelper
  # rubocop: disable CodeReuse/ActiveRecord
  def on_demand_scans_data(project)
    common_data(project).merge({
      'pipelines-count' => project.all_pipelines.where(source: Enums::Ci::Pipeline.sources[:ondemand_dast_scan]).count,
      'new-dast-scan-path' => new_project_on_demand_scan_path(project),
      'empty-state-svg-path' => image_path('illustrations/empty-state/ondemand-scan-empty.svg')
    })
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def on_demand_scans_form_data(project)
    common_data(project).merge({
      'default-branch' => project.default_branch,
      'profiles-library-path' => project_security_configuration_dast_scans_path(project),
      'scanner-profiles-library-path' => project_security_configuration_dast_scans_path(project, anchor: 'scanner-profiles'),
      'site-profiles-library-path' => project_security_configuration_dast_scans_path(project, anchor: 'site-profiles'),
      'new-scanner-profile-path' => new_project_security_configuration_dast_scans_dast_scanner_profile_path(project),
      'new-site-profile-path' => new_project_security_configuration_dast_scans_dast_site_profile_path(project),
      'timezones' => timezone_data(format: :full).to_json
    })
  end

  private

  def common_data(project)
    {
      'project-path' => project.path_with_namespace
    }
  end
end
