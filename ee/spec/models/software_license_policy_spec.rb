# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SoftwareLicensePolicy do
  subject { build(:software_license_policy) }

  describe 'validations' do
    it { is_expected.to include_module(Presentable) }
    it { is_expected.to validate_presence_of(:software_license) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:classification) }
    it { is_expected.to validate_uniqueness_of(:software_license).scoped_to(:project_id).with_message(/has already been taken/) }
  end

  describe ".with_license_by_name" do
    subject { described_class }

    let!(:mit_policy) { create(:software_license_policy, software_license: mit) }
    let!(:mit) { create(:software_license, :mit) }
    let!(:apache_policy) { create(:software_license_policy, software_license: apache) }
    let!(:apache) { create(:software_license, :apache_2_0) }

    it 'finds a license by an exact match' do
      expect(subject.with_license_by_name(mit.name)).to match_array([mit_policy])
    end

    it 'finds a license by a case insensitive match' do
      expect(subject.with_license_by_name('mIt')).to match_array([mit_policy])
    end

    it 'finds multiple licenses' do
      expect(subject.with_license_by_name([mit.name, apache.name])).to match_array([mit_policy, apache_policy])
    end
  end

  describe ".by_spdx" do
    let_it_be(:mit) { create(:software_license, :mit) }
    let_it_be(:mit_policy) { create(:software_license_policy, software_license: mit) }
    let_it_be(:apache) { create(:software_license, :apache_2_0) }
    let_it_be(:apache_policy) { create(:software_license_policy, software_license: apache) }

    it { expect(described_class.by_spdx(mit.spdx_identifier)).to match_array([mit_policy]) }
    it { expect(described_class.by_spdx([mit.spdx_identifier, apache.spdx_identifier])).to match_array([mit_policy, apache_policy]) }
    it { expect(described_class.by_spdx(SecureRandom.uuid)).to be_empty }
  end

  describe "#name" do
    specify { expect(subject.name).to eql(subject.software_license.name) }
  end

  describe "#approval_status" do
    where(:classification, :approval_status) do
      [
        %w[allowed approved],
        %w[denied blacklisted]
      ]
    end

    with_them do
      subject { build(:software_license_policy, classification: classification) }

      it { expect(subject.approval_status).to eql(approval_status) }
    end
  end

  describe ".to_classification" do
    where(:approval_status, :classification) do
      [
        %w[approved allowed],
        %w[blacklisted denied]
      ]
    end

    with_them do
      subject { described_class.to_classification(approval_status) }

      it { expect(subject).to eql(classification) }
    end
  end
end
