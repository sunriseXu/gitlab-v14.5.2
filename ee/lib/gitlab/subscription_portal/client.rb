# frozen_string_literal: true

module Gitlab
  module SubscriptionPortal
    class Client
      include SubscriptionPortal::Clients::Rest
      include SubscriptionPortal::Clients::Graphql

      ResponseError = Class.new(StandardError)

      class << self
        private

        def json_headers
          {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          }
        end

        def admin_headers
          json_headers.merge(
            {
              'X-Admin-Email' => EE::SUBSCRIPTION_PORTAL_ADMIN_EMAIL,
              'X-Admin-Token' => EE::SUBSCRIPTION_PORTAL_ADMIN_TOKEN
            }
          )
        end

        def customer_headers(email, token)
          json_headers.merge(
            {
              'X-Customer-Email' => email,
              'X-Customer-Token' => token
            }
          )
        end

        def parse_response(http_response)
          parsed_response = http_response.parsed_response

          case http_response.response
          when Net::HTTPSuccess
            { success: true, data: parsed_response }
          when Net::HTTPUnprocessableEntity
            { success: false, data: { errors: parsed_response['errors'] } }
          else
            { success: false, data: { errors: "HTTP status code: #{http_response.code}" } }
          end
        end
      end
    end
  end
end
