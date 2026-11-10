module Api
  module V1
    class EntrySeriesController < ApplicationController
      def create
        authorize EntrySeries
        creator = EntrySeriesCreator.new(
          user: current_user,
          attributes: entry_params,
          count: params[:entries_count],
          direction: params[:direction],
          kind: params[:kind],
          total_cents: params[:total_cents],
          interval_months: params[:interval_months]
        )

        if creator.call
          render json: { data: EntrySeriesBlueprint.render_as_hash(creator.series) }, status: :created
        else
          render_validation_errors(creator.series)
        end
      end

      private

      def entry_params
        params.permit(:category_id, :nature, :description, :amount_cents, :due_on, :status, :paid_on)
      end
    end
  end
end
