# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::Replication::FileRetriever, :geo do
  shared_examples_for 'returns necessary params for sending a file from an API endpoint' do
    subject { @subject ||= retriever.execute }

    context 'when the upload exists' do
      let(:retriever) { described_class.new(upload.id, extra_params) }

      context 'when the upload has a file' do
        before do
          FileUtils.mkdir_p(File.dirname(upload.absolute_path))
          FileUtils.touch(upload.absolute_path) unless File.exist?(upload.absolute_path)
        end

        context 'when the extra_params parameters match the upload' do
          let(:extra_params) { { id: upload.model_id, type: upload.model_type, checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' } }

          it 'returns the file in a success hash' do
            expect(subject).to include(code: :ok, message: 'Success')
            expect(subject[:file].file.path).to eq(upload.absolute_path)
          end
        end

        context 'when the extra_params id does not match the upload model_id' do
          let(:extra_params) { { id: 10000, type: upload.model_type, checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' } }

          it 'returns an error hash' do
            expect(subject).to include(code: :not_found, message: 'Invalid request')
          end
        end

        context 'when the extra_params type does not match the upload model_type' do
          let(:extra_params) { { id: upload.model_id, type: 'bad_type', checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' } }

          it 'returns an error hash' do
            expect(subject).to include(code: :not_found, message: 'Invalid request')
          end
        end

        context 'when the extra_params checksum does not match the upload checksum' do
          let(:extra_params) { { id: upload.model_id, type: upload.model_type, checksum: 'doesnotmatch' } }

          it 'returns an error hash' do
            expect(subject).to include(code: :not_found, message: 'Checksum mismatch')
          end
        end
      end

      context 'when the upload does not have a file' do
        let(:extra_params) { { id: upload.model_id, type: upload.model_type, checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' } }

        it 'returns an error hash' do
          expect(subject).to include(code: :not_found, geo_code: 'FILE_NOT_FOUND', message: match(/Upload #\d+ file not found/))
        end
      end
    end

    context 'when the upload does not exist' do
      it 'returns an error hash' do
        result = described_class.new(10000, {}).execute

        expect(result).to eq(code: :not_found, message: 'Upload not found')
      end
    end
  end

  describe '#execute' do
    context 'user avatar' do
      it_behaves_like "returns necessary params for sending a file from an API endpoint" do
        let(:upload) { create(:upload, model: create(:user)) }
      end
    end

    context 'group avatar' do
      it_behaves_like "returns necessary params for sending a file from an API endpoint" do
        let(:upload) { create(:upload, model: create(:group)) }
      end
    end

    context 'project avatar' do
      it_behaves_like "returns necessary params for sending a file from an API endpoint" do
        let(:upload) { create(:upload, model: create(:project)) }
      end
    end

    context 'with an attachment' do
      it_behaves_like "returns necessary params for sending a file from an API endpoint" do
        let(:upload) { create(:upload, :attachment_upload) }
      end
    end

    context 'with a snippet' do
      it_behaves_like "returns necessary params for sending a file from an API endpoint" do
        let(:upload) { create(:upload, :personal_snippet_upload) }
      end
    end

    context 'with file upload' do
      it_behaves_like "returns necessary params for sending a file from an API endpoint" do
        let(:upload) { create(:upload, :issuable_upload) }
      end
    end

    context 'with favicon upload' do
      it_behaves_like "returns necessary params for sending a file from an API endpoint" do
        let(:upload) { create(:upload, :favicon_upload) }
      end
    end

    context 'with namespace file upload' do
      it_behaves_like "returns necessary params for sending a file from an API endpoint" do
        let(:upload) { create(:upload, :namespace_upload) }
      end
    end
  end
end
