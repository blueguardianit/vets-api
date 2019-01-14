# frozen_string_literal: true

module Types
  module Users
    # Defines the fields on Account. Fields expose the data that may
    # be queried, and validated.
    #
    class AccountType < Types::BaseObject
      field :account_uuid, String, null: true
      field :errors, Types::ErrorType, null: true

      def account_uuid
        account&.uuid
      end

      def errors
        error_details object.dig(:errors)
      end

      private

      def account
        object.dig(:account)
      end
    end
  end
end
