# frozen_string_literal: true

FactoryBot.define do
  factory :scan_execution_policy, class: Struct.new(:name, :description, :enabled, :actions, :rules) do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      actions = attributes[:actions]
      rules = attributes[:rules]

      new(name, description, enabled, actions, rules).to_h
    end

    sequence(:name) { |n| "test-policy-#{n}" }
    description { 'This policy enforces to run DAST for every pipeline within the project' }
    enabled { true }
    rules { [{ type: 'pipeline', branches: %w[production] }] }
    actions { [{ scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' }] }

    trait :with_schedule do
      rules { [{ type: 'schedule', branches: %w[production], cadence: '*/15 * * * *' }] }
    end
  end

  factory :scan_result_policy, class: Struct.new(:name, :description, :enabled, :actions, :rules) do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      actions = attributes[:actions]
      rules = attributes[:rules]

      new(name, description, enabled, actions, rules).to_h
    end

    sequence(:name) { |n| "test-policy-#{n}" }
    description { 'This policy considers only container scanning and critical severities' }
    enabled { true }
    rules do
      [
        {
          type: 'scan_finding',
          branches: %w[master],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical]
        }
      ]
    end

    actions { [{ type: 'require_approval', approvals_required: 1, approvers: %w[admin] }] }
  end

  factory :orchestration_policy_yaml, class: Struct.new(:scan_execution_policy, :scan_result_policy) do
    skip_create

    initialize_with do
      scan_execution_policy = attributes[:scan_execution_policy]
      scan_result_policy = attributes[:scan_result_policy]

      YAML.dump(new(scan_execution_policy, scan_result_policy).to_h.compact.deep_stringify_keys)
    end
  end
end
