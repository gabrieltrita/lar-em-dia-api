module Api
  module V1
    class EntriesController < ApplicationController
      include Paginatable

      SCOPE_ERRORS = {
        "only_for_single_entry" => "status and paid_on can only change on a single entry (scope one)",
        "installment_amount_locked" => "The amount of an installment can only change on a single entry (scope one)"
      }.freeze

      before_action :set_entry, only: %i[show update destroy]

      def index
        authorize Entry
        pagy, entries = pagy(filtered_entries.includes(:series).chronological)
        render json: { data: EntryBlueprint.render_as_hash(entries), meta: pagination_meta(pagy) }
      rescue Date::Error
        render_error(status: :bad_request, code: "invalid_date", message: "from and to must be dates (YYYY-MM-DD)")
      end

      def show
        render json: { data: EntryBlueprint.render_as_hash(@entry) }
      end

      def create
        entry = current_user.entries.new(entry_params)
        authorize entry

        if entry.save
          render json: { data: EntryBlueprint.render_as_hash(entry) }, status: :created
        else
          render_validation_errors(entry)
        end
      end

      def update
        change = EntryScope.new(@entry, params[:scope])
        if change.update(entry_params)
          render json: { data: EntryBlueprint.render_as_hash(@entry.reload) }
        elsif change.error_code
          render_error(status: :unprocessable_content, code: change.error_code, message: SCOPE_ERRORS.fetch(change.error_code))
        else
          render_validation_errors(change.invalid_entry)
        end
      end

      def destroy
        EntryScope.new(@entry, params[:scope]).destroy
        head :no_content
      end

      private

      def set_entry
        @entry = policy_scope(Entry).find(params[:id])
        authorize @entry
      end

      def filtered_entries
        entries = policy_scope(Entry)
        entries = entries.where(kind: params[:kind]) if Entry.kinds.key?(params[:kind])
        entries = entries.where(nature: params[:nature]) if Entry.natures.key?(params[:nature])
        entries = entries.where(due_on: date_param(:from)..) if params[:from].present?
        entries = entries.where(due_on: ..date_param(:to)) if params[:to].present?
        entries
      end

      def date_param(name)
        Date.iso8601(params[name].to_s)
      end

      def entry_params
        params.permit(:category_id, :nature, :description, :amount_cents, :due_on, :status, :paid_on)
      end
    end
  end
end
