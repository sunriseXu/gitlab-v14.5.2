# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_statistic, class: 'Vulnerabilities::Statistic' do
    project

    trait :grade_a do
      info { 1 }
    end

    trait :grade_b do
      low { 1 }
    end

    trait :grade_c do
      medium { 1 }
    end

    trait :grade_d do
      high { 1 }
      unknown { 1 }
    end

    trait :grade_f do
      critical { 1 }
    end
  end
end
