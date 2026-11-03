module Api
  module V1
    class BalancesController < ApplicationController
      include Paginatable

      before_action :set_balance, only: %i[show update destroy]

      def index
        authorize Balance
        pagy, balances = pagy(policy_scope(Balance).recent)
        render json: { data: BalanceBlueprint.render_as_hash(balances), meta: pagination_meta(pagy) }
      end

      def show
        render json: { data: BalanceBlueprint.render_as_hash(@balance) }
      end

      def create
        balance = current_user.balances.new(balance_params)
        authorize balance

        if balance.save
          render json: { data: BalanceBlueprint.render_as_hash(balance) }, status: :created
        else
          render_validation_errors(balance)
        end
      end

      def update
        if @balance.update(balance_params)
          render json: { data: BalanceBlueprint.render_as_hash(@balance) }
        else
          render_validation_errors(@balance)
        end
      end

      def destroy
        @balance.destroy!
        head :no_content
      end

      private

      def set_balance
        @balance = policy_scope(Balance).find(params[:id])
        authorize @balance
      end

      def balance_params
        params.permit(:amount_cents, :as_of)
      end
    end
  end
end
