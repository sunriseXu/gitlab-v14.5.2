# frozen_string_literal: true

module Security
  # Service for alerting revocation service of leaked security tokens
  #
  class TokenRevocationService < ::BaseService
    RevocationFailedError = Class.new(StandardError)

    def initialize(revocable_keys:)
      @revocable_keys = revocable_keys
    end

    def execute
      raise RevocationFailedError, 'Missing revocation token data' if missing_token_data?

      return error('Token revocation is disabled') unless token_revocation_enabled?
      return success if revoke_token_body.blank?

      response = revoke_tokens
      response.success? ? success : error('Failed to revoke tokens')
    rescue RevocationFailedError => exception
      error(exception.message)
    rescue StandardError => exception
      log_token_revocation_error(exception)
      error(exception.message)
    end

    private

    def token_revocation_enabled?
      ::Gitlab::CurrentSettings.secret_detection_token_revocation_enabled?
    end

    def revoke_tokens
      ::Gitlab::HTTP.post(
        token_revocation_url,
        body: revoke_token_body,
        headers: {
         'Content-Type' => 'application/json',
         'Authorization' => revocation_api_token
        }
      )
    end

    def missing_token_data?
      token_revocation_url.blank? || token_types_url.blank? || revocation_api_token.blank?
    end

    def log_token_revocation_error(error)
      log_error(
        error: error.class.name,
        message: error.message,
        source: "#{__FILE__}:#{__LINE__}",
        backtrace: error.backtrace
      )
    end

    def revoke_token_body
      @revoke_token_body ||= begin
        response = ::Gitlab::HTTP.get(
          token_types_url,
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => revocation_api_token
          }
        )
        raise RevocationFailedError, 'Failed to get revocation token types' unless response.success?

        token_types = ::Gitlab::Json.parse(response.body)['types']
        return if token_types.blank?

        @revocable_keys.filter! { |key| token_types.include?(key[:type]) }
        return if @revocable_keys.blank?

        @revocable_keys.to_json
      end
    end

    def token_types_url
      ::Gitlab::CurrentSettings.secret_detection_revocation_token_types_url
    end

    def token_revocation_url
      ::Gitlab::CurrentSettings.secret_detection_token_revocation_url
    end

    def revocation_api_token
      ::Gitlab::CurrentSettings.secret_detection_token_revocation_token
    end
  end
end
