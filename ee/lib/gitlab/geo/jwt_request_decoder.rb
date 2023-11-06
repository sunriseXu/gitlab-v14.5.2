# frozen_string_literal: true

module Gitlab
  module Geo
    class JwtRequestDecoder
      include LogHelpers
      include ::Gitlab::Utils::StrongMemoize

      IAT_LEEWAY = 60.seconds.to_i

      def self.geo_auth_attempt?(header)
        token_type, = header&.split(' ', 2)
        token_type == ::Gitlab::Geo::BaseRequest::GITLAB_GEO_AUTH_TOKEN_TYPE
      end

      attr_reader :auth_header

      def initialize(auth_header)
        @include_disabled = false
        @auth_header = auth_header
      end

      # Return decoded attributes from given header
      #
      # @return [Hash] decoded attributes
      def decode
        strong_memoize(:decoded_authorization) do
          decode_geo_request
        end
      end

      def include_disabled!
        @include_disabled = true
      end

      # Check if set of attributes match against attributes decoded from JWT
      #
      # @param [Hash] attributes to be matched against JWT
      # @return bool true
      def valid_attributes?(**attributes)
        decoded_attributes = decode

        return false if decoded_attributes.nil?

        attributes.all? { |attribute, value| decoded_attributes[attribute] == value }
      end

      private

      def decode_geo_request
        # A Geo request has an Authorization header:
        # Authorization: GL-Geo: <Geo Access Key>:<JWT payload>
        #
        # For example:
        # JWT payload = { "data": { "oid": "12345" }, iat: 123456 }
        #
        begin
          data = decode_auth_header
        rescue OpenSSL::Cipher::CipherError
          message = 'Error decrypting the Geo secret from the database. Check that the primary and secondary have the same db_key_base.'
          log_error(message)
          raise InvalidDecryptionKeyError, message
        end

        return unless data.present?

        secret, encoded_message = data

        begin
          decoded = JWT.decode(
            encoded_message,
            secret,
            true,
            { leeway: IAT_LEEWAY, verify_iat: true, algorithm: 'HS256' }
          )

          message = decoded.first
          data = Gitlab::Json.parse(message['data']) if message
          data&.deep_symbolize_keys!
          data
        rescue JWT::ImmatureSignature, JWT::ExpiredSignature
          message = "Signature not within leeway of #{IAT_LEEWAY} seconds. Check your system clocks!"
          log_error(message)
          raise InvalidSignatureTimeError, message
        rescue JWT::DecodeError => e
          log_error("Error decoding Geo request: #{e}")
          nil
        end
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def hmac_secret(access_key)
        node_params = { access_key: access_key }

        # By default, we fail authorization for requests from disabled nodes because
        # it is a convenient place to block nearly all requests from disabled
        # secondaries. The `include_disabled` option can safely override this
        # check for `enabled`.
        #
        # A request is authorized if the access key in the Authorization header
        # matches the access key of the requesting node, **and** the decoded data
        # matches the requested resource.
        node_params[:enabled] = true unless @include_disabled

        @geo_node ||= GeoNode.find_by(node_params)
        @geo_node&.secret_access_key
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def decode_auth_header
        return unless auth_header.present?

        tokens = auth_header.split(' ')

        return unless tokens.count == 2
        return unless tokens[0] == Gitlab::Geo::BaseRequest::GITLAB_GEO_AUTH_TOKEN_TYPE

        # Split at the first occurrence of a colon
        geo_tokens = tokens[1].split(':', 2)

        return unless geo_tokens.count == 2

        access_key = geo_tokens[0]
        encoded_message = geo_tokens[1]
        secret = hmac_secret(access_key)

        return unless secret.present?

        [secret, encoded_message]
      end
    end
  end
end
