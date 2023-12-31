# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ShaAttribute do
  let(:model) { Class.new(ApplicationRecord) { include ShaAttribute } }

  before do
    columns = [
      double(:column, name: 'name', type: :text),
      double(:column, name: 'sha1', type: :binary)
    ]

    allow(model).to receive(:columns).and_return(columns)
  end

  describe '#sha_attribute' do
    context 'when in development' do
      before do
        stub_rails_env('development')
      end

      context 'when the table exists' do
        before do
          allow(model).to receive(:table_exists?).and_return(true)
        end

        it 'defines a SHA attribute for a binary column' do
          expect(model).to receive(:attribute)
            .with(:sha1, an_instance_of(Gitlab::Database::ShaAttribute))

          model.sha_attribute(:sha1)
        end

        it 'raises ArgumentError when the column type is not :binary' do
          expect { model.sha_attribute(:name) }.to raise_error(ArgumentError)
        end
      end

      context 'when the table does not exist' do
        it 'allows the attribute to be added' do
          allow(model).to receive(:table_exists?).and_return(false)

          expect(model).not_to receive(:columns)
          expect(model).to receive(:attribute)

          model.sha_attribute(:name)
        end
      end

      context 'when the column does not exist' do
        it 'allows the attribute to be added' do
          allow(model).to receive(:table_exists?).and_return(true)

          expect(model).to receive(:columns)
          expect(model).to receive(:attribute)

          model.sha_attribute(:no_name)
        end
      end

      context 'when other execeptions are raised' do
        it 'logs and re-rasises the error' do
          allow(model).to receive(:table_exists?).and_raise(ActiveRecord::NoDatabaseError.new('does not exist'))

          expect(model).not_to receive(:columns)
          expect(model).not_to receive(:attribute)
          expect(Gitlab::AppLogger).to receive(:error)

          expect { model.sha_attribute(:name) }.to raise_error(ActiveRecord::NoDatabaseError)
        end
      end
    end

    context 'when in production' do
      before do
        stub_rails_env('production')
      end

      it 'defines a SHA attribute' do
        expect(model).not_to receive(:table_exists?)
        expect(model).not_to receive(:columns)
        expect(model).to receive(:attribute).with(:sha1, an_instance_of(Gitlab::Database::ShaAttribute))

        model.sha_attribute(:sha1)
      end
    end
  end
end
