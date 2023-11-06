# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Reports::LicenseScanning::Report do
  include LicenseScanningReportHelpers

  describe '#by_license_name' do
    subject { report.by_license_name(name) }

    let(:report) { build(:ci_reports_license_scanning_report, :report_2) }

    context 'with existing license' do
      let(:name) { 'MIt' }

      it 'finds right name' do
        is_expected.to be_a(Gitlab::Ci::Reports::LicenseScanning::License)
        expect(subject.name).to eq('MIT')
      end
    end

    context 'without existing license' do
      let(:name) { 'TIM' }

      it { is_expected.to be_nil }
    end
  end

  describe '#merge_dependencies_info!' do
    subject { report.merge_dependencies_info!(dependencies) }

    let(:report) { build(:ci_reports_license_scanning_report, :report_2) }
    let(:dependency_list_report) { Gitlab::Ci::Reports::DependencyList::Report.new }

    context 'without licensed dependencies' do
      let(:library1) { build(:dependency, name: 'Library1') }
      let(:library3) { build(:dependency, name: 'Library3') }
      let(:dependencies) { [library3, library1] }

      before do
        subject
      end

      it 'does not merge dependency path' do
        paths = all_dependency_paths(report)

        expect(paths).to be_empty
      end
    end

    context 'with licensed dependencies' do
      let(:library1) { build(:dependency, :with_licenses, name: 'Library1') }
      let(:library3) { build(:dependency, :with_licenses, name: 'Library3') }
      let(:library4) { build(:dependency, :with_licenses, name: 'Library4') }
      let(:dependencies) { [library1, library3, library4] }

      let(:mit_license) { report.by_license_name('MIT') }
      let(:apache_license) { report.by_license_name('Apache 2.0') }

      before do
        mit_license.add_dependency(name: 'Library4')
        apache_license.add_dependency(name: 'Library3')

        subject
      end

      it 'merge path to matched dependencies' do
        dep1 = dependency_by_name(mit_license, 'Library1')
        dep4 = dependency_by_name(mit_license, 'Library4')
        dep3 = dependency_by_name(apache_license, 'Library3')

        expect(dep1.path).to eq(library1.dig(:location, :blob_path))
        expect(dep4.path).to eq(library4.dig(:location, :blob_path))
        expect(dep3.path).to be_nil
      end
    end
  end

  describe '#violates?' do
    subject { report.violates?(project.software_license_policies) }

    let(:project) { create(:project) }

    context "when checking for violations using v1 license scan report" do
      let(:report) { build(:license_scan_report) }

      let(:mit_license) { build(:software_license, :mit, spdx_identifier: nil) }
      let(:apache_license) { build(:software_license, :apache_2_0, spdx_identifier: nil) }

      before do
        report
          .add_license(id: nil, name: 'MIT')
          .add_dependency(name: 'rails')
      end

      context 'when a denied license is found in the report' do
        let(:denied_policy) { build(:software_license_policy, :denied, software_license: mit_license) }

        before do
          project.software_license_policies << denied_policy
        end

        it { is_expected.to be_truthy }
      end

      context 'when a denied license is discovered with a different casing for the name' do
        let(:denied_policy) { build(:software_license_policy, :denied, software_license: mit_license) }

        before do
          mit_license.update!(name: 'mit')
          project.software_license_policies << denied_policy
        end

        it { is_expected.to be_truthy }
      end

      context 'when none of the licenses discovered in the report violate the denied policy' do
        let(:denied_policy) { build(:software_license_policy, :denied, software_license: apache_license) }

        before do
          project.software_license_policies << denied_policy
        end

        it { is_expected.to be_falsey }
      end
    end

    context "when checking for violations using the v2 license scan reports" do
      let(:report) { build(:license_scan_report) }

      context "when a denied license with a SPDX identifier is also in the report" do
        let(:mit_spdx_id) { 'MIT' }
        let(:mit_license) { build(:software_license, :mit, spdx_identifier: mit_spdx_id) }
        let(:mit_policy) { build(:software_license_policy, :denied, software_license: mit_license) }

        before do
          report.add_license(id: mit_spdx_id, name: 'MIT License')
          project.software_license_policies << mit_policy
        end

        it { is_expected.to be_truthy }
      end

      context "when a denied license does not have an SPDX identifier because it was provided by an end user" do
        let(:custom_license) { build(:software_license, name: 'custom', spdx_identifier: nil) }
        let(:custom_policy) { build(:software_license_policy, :denied, software_license: custom_license) }

        before do
          report.add_license(id: nil, name: 'Custom')
          project.software_license_policies << custom_policy
        end

        it { is_expected.to be_truthy }
      end

      context "when none of the licenses discovered match any of the denied software policies" do
        let(:apache_license) { build(:software_license, :apache_2_0, spdx_identifier: 'Apache-2.0') }
        let(:apache_policy) { build(:software_license_policy, :denied, software_license: apache_license) }

        before do
          report.add_license(id: nil, name: 'Custom')
          report.add_license(id: 'MIT', name: 'MIT License')
          project.software_license_policies << apache_policy
        end

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#diff_with' do
    subject { base_report.diff_with(head_report) }

    def names_from(licenses)
      licenses.map(&:name)
    end

    context 'when the other report is not available' do
      let(:base_report) { build(:license_scan_report, :version_2) }
      let(:head_report) { nil }

      before do
        base_report
          .add_license(id: 'MIT', name: 'MIT License')
          .add_dependency(name: 'rails')
      end

      specify do
        expect(names_from(subject[:removed])).to contain_exactly('MIT License')
        expect(subject[:added]).to be_empty
        expect(subject[:unchanged]).to be_empty
      end
    end

    context 'when diffing two v1 reports' do
      let(:base_report) { build(:license_scan_report, :version_1) }
      let(:head_report) { build(:license_scan_report, :version_1) }

      before do
        base_report.add_license(id: nil, name: 'MIT').add_dependency(name: 'Library1')
        base_report.add_license(id: nil, name: 'BSD').add_dependency(name: 'Library1')
        base_report.add_license(id: nil, name: 'WTFPL').add_dependency(name: 'Library2')

        head_report.add_license(id: nil, name: 'MIT').add_dependency(name: 'Library1')
        head_report.add_license(id: nil, name: 'Apache 2.0').add_dependency(name: 'Library3')
        head_report.add_license(id: nil, name: 'bsd').add_dependency(name: 'Library1')
      end

      it { expect(names_from(subject[:added])).to contain_exactly('Apache 2.0') }
      it { expect(names_from(subject[:unchanged])).to contain_exactly('MIT', 'BSD') }
      it { expect(names_from(subject[:removed])).to contain_exactly('WTFPL') }
    end

    context 'when diffing two v2 reports' do
      let(:base_report) { build(:license_scan_report, :version_2) }
      let(:head_report) { build(:license_scan_report, :version_2) }

      before do
        base_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'Library1')
        base_report.add_license(id: 'BSD-3-Clause', name: 'BSD').add_dependency(name: 'Library1')
        base_report.add_license(id: 'WTFPL', name: 'WTFPL').add_dependency(name: 'Library2')

        head_report.add_license(id: 'BSD-3-Clause', name: 'bsd').add_dependency(name: 'Library1')
        head_report.add_license(id: 'Apache-2.0', name: 'Apache 2.0').add_dependency(name: 'Library3')
        head_report.add_license(id: 'MIT', name: 'MIT License').add_dependency(name: 'Library1')
      end

      it { expect(names_from(subject[:added])).to contain_exactly('Apache 2.0') }
      it { expect(names_from(subject[:unchanged])).to contain_exactly('MIT', 'BSD') }
      it { expect(names_from(subject[:removed])).to contain_exactly('WTFPL') }
    end

    context 'when diffing a v1 report with a v2 report' do
      let(:base_report) { build(:license_scan_report, :version_1) }
      let(:head_report) { build(:license_scan_report, :version_2) }

      before do
        base_report.add_license(id: nil, name: 'MIT').add_dependency(name: 'Library1')
        base_report.add_license(id: nil, name: 'BSD').add_dependency(name: 'Library1')
        base_report.add_license(id: nil, name: 'WTFPL').add_dependency(name: 'Library2')

        head_report.add_license(id: 'BSD-3-Clause', name: 'bsd').add_dependency(name: 'Library1')
        head_report.add_license(id: 'Apache-2.0', name: 'Apache 2.0').add_dependency(name: 'Library3')
        head_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'Library1')
      end

      it { expect(names_from(subject[:added])).to contain_exactly('Apache 2.0') }
      it { expect(names_from(subject[:unchanged])).to contain_exactly('MIT', 'BSD') }
      it { expect(names_from(subject[:removed])).to contain_exactly('WTFPL') }
    end

    context 'when diffing a v2 report with a v1 report' do
      let(:base_report) { build(:license_scan_report, :version_2) }
      let(:head_report) { build(:license_scan_report, :version_1) }

      before do
        base_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'Library1')
        base_report.add_license(id: 'BSD-3-Clause', name: 'BSD').add_dependency(name: 'Library1')
        base_report.add_license(id: 'WTFPL', name: 'WTFPL').add_dependency(name: 'Library2')

        head_report.add_license(id: nil, name: 'bsd').add_dependency(name: 'Library1')
        head_report.add_license(id: nil, name: 'Apache 2.0').add_dependency(name: 'Library3')
        head_report.add_license(id: nil, name: 'MIT').add_dependency(name: 'Library1')
      end

      it { expect(names_from(subject[:added])).to contain_exactly('Apache 2.0') }
      it { expect(names_from(subject[:unchanged])).to contain_exactly('MIT', 'BSD') }
      it { expect(names_from(subject[:removed])).to contain_exactly('WTFPL') }
    end
  end

  describe '#empty?' do
    let(:completed_report) { build(:ci_reports_license_scanning_report, :report_1) }
    let(:empty_report) { build(:ci_reports_license_scanning_report) }

    it { expect(empty_report).to be_empty }
    it { expect(completed_report).not_to be_empty }
  end

  describe '.parse_from' do
    context 'when parsing a v1 report' do
      subject { described_class.parse_from(v1_json) }

      let(:v1_json) { fixture_file('security_reports/master/gl-license-scanning-report.json', dir: 'ee') }

      it { expect(subject.version).to eql('1.0') }
      it { expect(subject.licenses.count).to eq(4) }
    end

    context 'when parsing a v2 report' do
      subject { described_class.parse_from(v2_json) }

      let(:v2_json) { fixture_file('security_reports/license_compliance/gl-license-scanning-report-v2.json', dir: 'ee') }

      it { expect(subject.version).to eql('2.0') }
      it { expect(subject.licenses.count).to eq(3) }
    end
  end
end
