module Api
  module V1
    class ReserveMovementsController < ApplicationController
      include Paginatable

      FIELDS = %i[account_id kind moved_on amount_cents debit_balance].freeze

      before_action :set_movement, only: %i[show update destroy]

      def index
        authorize ReserveMovement
        pagy, movements = pagy(filtered_movements.chronological)
        render json: { data: ReserveMovementBlueprint.render_as_hash(movements), meta: pagination_meta(pagy) }
      rescue Date::Error
        render_error(status: :bad_request, code: "invalid_date", message: "from and to must be dates (YYYY-MM-DD)")
      end

      def show
        render json: { data: ReserveMovementBlueprint.render_as_hash(@movement) }
      end

      def create
        recorder = ReserveMovementRecorder.new(current_user)
        authorize recorder.record
        respond(recorder, recorder.create(movement_params), :created)
      end

      def update
        recorder = ReserveMovementRecorder.new(current_user, @movement)
        respond(recorder, recorder.update(movement_params), :ok)
      end

      def destroy
        recorder = ReserveMovementRecorder.new(current_user, @movement)
        if recorder.destroy
          render json: { data: { deleted_id: @movement.id } }
        else
          render_error(status: :unprocessable_content, code: recorder.error_code,
            message: "Deleting this movement would leave a later withdrawal without enough money")
        end
      end

      private

      def set_movement
        @movement = policy_scope(ReserveMovement).find(params[:id])
        authorize @movement
      end

      def respond(recorder, saved, status)
        return render_validation_errors(recorder.record) unless saved

        render json: { data: ReserveMovementBlueprint.render_as_hash(recorder.record) }, status: status
      end

      def filtered_movements
        movements = policy_scope(ReserveMovement)
        movements = movements.where(account_id: params[:account_id].to_s) if params[:account_id].present?
        movements = movements.where(moved_on: Date.iso8601(params[:from].to_s)..) if params[:from].present?
        movements = movements.where(moved_on: ..Date.iso8601(params[:to].to_s)) if params[:to].present?
        movements
      end

      def movement_params
        params.permit(*FIELDS).to_h.symbolize_keys
      end
    end
  end
end
