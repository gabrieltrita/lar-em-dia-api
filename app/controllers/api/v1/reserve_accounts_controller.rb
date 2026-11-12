module Api
  module V1
    class ReserveAccountsController < ApplicationController
      FIELDS = %i[name kind cdi_percent_bps annual_rate_bps tax_exempt].freeze

      before_action :set_account, only: %i[show update destroy]

      def index
        authorize ReserveAccount
        render json: { data: ReserveAccountBlueprint.render_as_hash(policy_scope(ReserveAccount).ordered) }
      end

      def show
        render json: { data: ReserveAccountBlueprint.render_as_hash(@account) }
      end

      def create
        account = current_user.reserve_accounts.new(account_params)
        authorize account
        return render_validation_errors(account) unless account.save

        render json: { data: ReserveAccountBlueprint.render_as_hash(account) }, status: :created
      end

      def update
        return render_validation_errors(@account) unless @account.update(account_params)

        render json: { data: ReserveAccountBlueprint.render_as_hash(@account) }
      end

      def destroy
        @account.destroy_with_entries!
        render json: { data: { deleted_id: @account.id } }
      end

      private

      def set_account
        @account = policy_scope(ReserveAccount).find(params[:id])
        authorize @account
      end

      def account_params
        params.permit(*FIELDS)
      end
    end
  end
end
