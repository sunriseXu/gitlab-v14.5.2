# frozen_string_literal: true

module EE
  module RemoteMirror
    extend ActiveSupport::Concern

    def sync?
      super && !::Gitlab::Geo.secondary?
    end
  end
end
