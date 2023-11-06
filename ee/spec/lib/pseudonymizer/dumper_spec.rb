# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Pseudonymizer::Dumper do
  let!(:project) { create(:project) }
  let(:base_dir) { Dir.mktmpdir }
  let(:options) do
    Pseudonymizer::Options.new(
      config: YAML.load_file(Gitlab.config.pseudonymizer.manifest)
    )
  end

  subject(:pseudo) { described_class.new(options) }

  before do
    allow(options).to receive(:output_dir).and_return(base_dir)
  end

  after do
    FileUtils.rm_rf(base_dir)
  end

  describe '#tables_to_csv' do
    let(:column_names) { %w(id name path description) }

    def decode_project_csv(project_table_file)
      columns = []
      project_data = []

      Zlib::GzipReader.open(project_table_file) do |gz|
        csv = CSV.new(gz, headers: true)
        # csv.shift # read the header row
        project_data = csv.gets
        columns = csv.headers
      end

      [columns, project_data]
    end

    context 'with nil pseudo fields' do
      before do
        pseudo.config[:tables] = {
          projects: {
            whitelist: column_names,
            pseudo: nil
          }
        }
      end

      it 'outputs valid values' do
        project_table_file = pseudo.tables_to_csv[0]
        columns, project_data = decode_project_csv(project_table_file)

        # check if CSV columns are correct
        expect(columns).to include(*column_names)

        column_names.each do |column|
          expect(project_data[column].to_s).to eq(project[column].to_s)
        end
      end
    end

    context 'with pseudo fields' do
      it 'outputs project tables to csv' do
        pseudo.config[:tables] = {
          projects: {
            whitelist: column_names,
            pseudo: %w(id)
          }
        }

        expect(pseudo.output_dir).to eq(base_dir)

        # grab the first table it outputs. There would only be 1.
        project_table_file = pseudo.tables_to_csv[0]
        expect(project_table_file).to end_with("projects.csv.gz")

        columns, project_data = decode_project_csv(project_table_file)

        # check if CSV columns are correct
        expect(columns).to include(*column_names)

        # is it pseudonymous
        # sha 256 is 64 chars in length
        expect(project_data["id"].length).to eq(64)
      end

      it "warns when pseudonymized fields are extraneous" do
        column_names = %w(id name path description)
        pseudo.config[:tables] = {
          projects: {
            whitelist: column_names,
            pseudo: %w(id extraneous)
          }
        }

        expect(Gitlab::AppLogger).to receive(:warn).with(/extraneous/)

        pseudo.tables_to_csv
      end
    end
  end

  describe "manifest is valid" do
    it "all tables exist" do
      existing_tables = ActiveRecord::Base.connection.tables
      tables = options.config['tables'].keys

      expect(existing_tables).to include(*tables)
    end

    it "all whitelisted attributes exist" do
      options.config['tables'].each do |table, table_def|
        whitelisted = table_def.fetch('whitelist', [])
        existing_columns = ActiveRecord::Base.connection.columns(table.to_sym).map(&:name)
        diff = whitelisted - existing_columns

        expect(diff).to be_empty, "#{table} should define columns #{whitelisted.inspect}: missing #{diff.inspect}"
      end
    end

    it "all pseudonymized attributes are whitelisted" do
      options.config['tables'].each do |table, table_def|
        whitelisted = table_def.fetch('whitelist', [])
        pseudonymized = table_def.fetch('pseudo', [])
        diff = pseudonymized - whitelisted

        expect(diff).to be_empty, "#{table} should whitelist columns #{pseudonymized.inspect}: missing #{diff.inspect}"
      end
    end
  end
end
