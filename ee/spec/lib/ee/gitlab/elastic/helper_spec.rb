# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::Helper, :request_store do
  subject(:helper) { described_class.default }

  shared_context 'with a legacy index' do
    before do
      @index_name = helper.create_empty_index(with_alias: false, options: { index_name: helper.target_name }).each_key.first
    end
  end

  shared_context 'with an existing index and alias' do
    before do
      @index_name = helper.create_empty_index(with_alias: true).each_key.first
    end
  end

  after do
    helper.delete_index(index_name: @index_name) if @index_name
  end

  describe '.new' do
    it 'has the proper default values' do
      expect(helper).to have_attributes(
        version: ::Elastic::MultiVersionUtil::TARGET_VERSION,
        target_name: ::Elastic::Latest::Config.index_name)
    end

    context 'with a custom `index_name`' do
      let(:index_name) { 'custom-index-name' }

      subject(:helper) { described_class.new(target_name: index_name) }

      it 'has the proper `index_name`' do
        expect(helper).to have_attributes(target_name: index_name)
      end
    end
  end

  describe '.default' do
    it 'does not cache the value' do
      expect(described_class.default.object_id).not_to eq(described_class.default.object_id)
    end
  end

  describe '#default_mappings' do
    it 'has only one type' do
      expect(helper.default_mappings.keys).to match_array %i(doc)
    end

    context 'custom analyzers' do
      let(:custom_analyzers_mappings) { { doc: { properties: { title: { fields: { custom: true } } } } } }

      before do
        allow(::Elastic::Latest::CustomLanguageAnalyzers).to receive(:custom_analyzers_mappings).and_return(custom_analyzers_mappings)
      end

      it 'merges custom language analyzers mappings' do
        expect(helper.default_mappings[:doc][:properties][:title]).to include(custom_analyzers_mappings[:doc][:properties][:title])
      end
    end
  end

  describe '#create_migrations_index' do
    after do
      helper.delete_migrations_index
    end

    it 'creates the index' do
      expect { helper.create_migrations_index }
             .to change { helper.migrations_index_exists? }
             .from(false).to(true)
    end
  end

  describe '#create_standalone_indices', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/297357' do
    after do
      @indices.each do |index_name, _|
        helper.delete_index(index_name: index_name)
      end
    end

    it 'creates standalone indices' do
      @indices = helper.create_standalone_indices

      @indices.each do |index|
        expect(helper.index_exists?(index_name: index)).to be_truthy
      end
    end

    it 'raises an exception when there is an existing alias' do
      @indices = helper.create_standalone_indices

      expect { helper.create_standalone_indices }.to raise_error(/already exists/)
    end

    it 'does not raise an exception with skip_if_exists option' do
      @indices = helper.create_standalone_indices

      expect { helper.create_standalone_indices(options: { skip_if_exists: true }) }.not_to raise_error
    end

    it 'raises an exception when there is an existing index' do
      @indices = helper.create_standalone_indices(with_alias: false)

      expect { helper.create_standalone_indices(with_alias: false) }.to raise_error(/already exists/)
    end
  end

  describe '#delete_standalone_indices', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/297357' do
    before do
      helper.create_standalone_indices
    end

    subject { helper.delete_standalone_indices }

    it_behaves_like 'deletes all standalone indices'
  end

  describe '#delete_migrations_index' do
    before do
      helper.create_migrations_index
    end

    it 'deletes the migrations index' do
      expect { helper.delete_migrations_index }
             .to change { helper.migrations_index_exists? }
             .from(true).to(false)
    end
  end

  describe '#create_empty_index' do
    context 'with an empty cluster' do
      context 'with alias and index' do
        include_context 'with an existing index and alias'

        it 'creates index and alias' do
          expect(helper.index_exists?).to eq(true)
          expect(helper.alias_exists?).to eq(true)
        end
      end

      context 'when there is a legacy index' do
        include_context 'with a legacy index'

        it 'creates the index only' do
          expect(helper.index_exists?).to eq(true)
          expect(helper.alias_exists?).to eq(false)
        end
      end

      it 'creates an index with a custom name' do
        @index_name = 'test-custom-index-name'

        helper.create_empty_index(with_alias: false, options: { index_name: @index_name })

        expect(helper.index_exists?(index_name: @index_name)).to eq(true)
        expect(helper.index_exists?).to eq(false)
      end
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it 'raises an error' do
        expect { helper.create_empty_index }.to raise_error(/Index under '.+' already exists/)
      end

      it 'does not raise error with skip_if_exists option' do
        expect { helper.create_empty_index(options: { skip_if_exists: true }) }.not_to raise_error
      end
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it 'raises an error' do
        expect { helper.create_empty_index }.to raise_error(/Index or alias under '.+' already exists/)
      end
    end
  end

  describe '#delete_index' do
    subject { helper.delete_index }

    context 'without an existing index' do
      it 'fails gracefully' do
        is_expected.to be_falsy
      end
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it { is_expected.to be_truthy }
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to be_truthy }
    end
  end

  describe '#index_exists?' do
    subject { helper.index_exists? }

    context 'without an existing index' do
      it { is_expected.to be_falsy }
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to be_truthy }
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it { is_expected.to be_truthy }
    end
  end

  describe '#migrations_index_exists?' do
    subject { helper.migrations_index_exists? }

    context 'without an existing migrations index' do
      before do
        helper.delete_migrations_index
      end

      it { is_expected.to be_falsy }
    end

    context 'when it exists' do
      before do
        helper.create_migrations_index
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#alias_exists?' do
    subject { helper.alias_exists? }

    context 'without an existing index' do
      it { is_expected.to be_falsy }
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to be_falsy }
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it { is_expected.to be_truthy }
    end
  end

  describe '#alias_missing?' do
    it 'is the opposite of #alias_exists?' do
      expect(helper.alias_missing?).to eq(!helper.alias_exists?)
    end
  end

  describe '#cluster_free_size_bytes' do
    it 'returns valid cluster size' do
      expect(helper.cluster_free_size_bytes).to be_positive
    end
  end

  describe '#switch_alias' do
    include_context 'with an existing index and alias'

    let(:new_index_name) { 'test-switch-alias' }

    it 'switches the alias' do
      helper.create_empty_index(with_alias: false, options: { index_name: new_index_name })

      expect { helper.switch_alias(to: new_index_name) }
      .to change { helper.target_index_name }.to(new_index_name)

      helper.delete_index(index_name: new_index_name)
    end
  end

  describe '#index_size' do
    subject { helper.index_size }

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to have_key("docs") }
      it { is_expected.to have_key("store") }
    end

    context 'when there is an alias', :aggregate_failures do
      include_context 'with an existing index and alias'

      it { is_expected.to have_key("docs") }
      it { is_expected.to have_key("store") }

      it 'supports providing the alias name' do
        alias_name = helper.target_name

        expect(helper.index_size(index_name: alias_name)).to have_key("docs")
        expect(helper.index_size(index_name: alias_name)).to have_key("store")
      end
    end
  end

  describe '#documents_count' do
    subject { helper.documents_count }

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to eq(0) }
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it { is_expected.to eq(0) }

      it 'supports providing the alias name' do
        alias_name = helper.target_name

        expect(helper.documents_count(index_name: alias_name)).to eq(0)
      end
    end
  end

  describe '#delete_migration_record', :elastic do
    let(:migration) { ::Elastic::DataMigrationService.migrations.last }

    subject { helper.delete_migration_record(migration) }

    context 'when record exists' do
      it { is_expected.to be_truthy }
    end

    context 'when record does not exist' do
      before do
        allow(migration).to receive(:version).and_return(1)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#standalone_indices_proxies' do
    subject { helper.standalone_indices_proxies(target_classes: classes) }

    context 'when target_classes is not provided' do
      let(:classes) { nil }

      it 'creates proxies for each separate class' do
        expect(subject.count).to eq(Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES.count)
      end
    end

    context 'when target_classes is provided' do
      let(:classes) { [Issue] }

      it 'creates proxies for only the target classes' do
        expect(subject.count).to eq(1)
      end
    end
  end

  describe '#ping?' do
    subject { helper.ping? }

    it 'does not raise any exception' do
      allow(Gitlab::Elastic::Helper.default.client).to receive(:ping).and_raise(StandardError)

      expect(subject).to be_falsey
      expect { subject }.not_to raise_exception
    end
  end
end
