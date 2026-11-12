module Api
  module V1
    class InvestmentTransactionsController < ApplicationController
      include Paginatable

      FIELDS = %i[ticker kind traded_on quantity price_cents fees_cents goal debit_balance].freeze

      before_action :set_transaction, only: %i[show update destroy]

      def index
        authorize InvestmentTransaction
        pagy, transactions = pagy(filtered_transactions.includes(position: :asset).chronological)
        render json: { data: InvestmentTransactionBlueprint.render_as_hash(transactions), meta: pagination_meta(pagy) }
      rescue Date::Error
        render_error(status: :bad_request, code: "invalid_date", message: "from and to must be dates (YYYY-MM-DD)")
      end

      def show
        render json: { data: InvestmentTransactionBlueprint.render_as_hash(@transaction) }
      end

      def create
        recorder = InvestmentTransactionRecorder.new(current_user)
        authorize recorder.record
        respond(recorder, recorder.create(transaction_params), :created)
      end

      def update
        recorder = InvestmentTransactionRecorder.new(current_user, @transaction)
        respond(recorder, recorder.update(transaction_params), :ok)
      end

      def destroy
        recorder = InvestmentTransactionRecorder.new(current_user, @transaction)
        if recorder.destroy
          render json: { data: { deleted_id: @transaction.id } }
        else
          render_error(status: :unprocessable_content, code: recorder.error_code,
            message: "Deleting this transaction would leave a later sale without enough shares")
        end
      end

      private

      def set_transaction
        @transaction = policy_scope(InvestmentTransaction).find(params[:id])
        authorize @transaction
      end

      def respond(recorder, saved, status)
        return render_validation_errors(recorder.record) unless saved

        render json: { data: InvestmentTransactionBlueprint.render_as_hash(recorder.record) }, status: status
      end

      def filtered_transactions
        transactions = policy_scope(InvestmentTransaction)
        transactions = transactions.joins(position: :asset).where(assets: { ticker: params[:ticker].to_s.upcase }) if params[:ticker].present?
        transactions = transactions.where(traded_on: Date.iso8601(params[:from].to_s)..) if params[:from].present?
        transactions = transactions.where(traded_on: ..Date.iso8601(params[:to].to_s)) if params[:to].present?
        transactions
      end

      def transaction_params
        params.permit(*FIELDS).to_h.symbolize_keys
      end
    end
  end
end
