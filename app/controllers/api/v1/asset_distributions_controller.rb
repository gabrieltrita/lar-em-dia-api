module Api
  module V1
    class AssetDistributionsController < ApplicationController
      include Paginatable

      FIELDS = %i[kind record_on paid_on amount_per_share_e8].freeze

      before_action :set_distribution, only: %i[update destroy]

      def index
        authorize AssetDistribution
        distributions = policy_scope(AssetDistribution).includes(:asset).newest_first
        distributions = distributions.joins(:asset).where(assets: { ticker: params[:ticker].to_s.upcase }) if params[:ticker].present?
        pagy, distributions = pagy(distributions)
        render json: { data: AssetDistributionBlueprint.render_as_hash(distributions), meta: pagination_meta(pagy) }
      end

      def create
        distribution = current_user.asset_distributions.new(source: :manual, asset: Asset.find_by(ticker: params[:ticker].to_s.upcase))
        authorize distribution
        save(distribution, :created)
      end

      def update
        if params.key?(:ticker) && params[:ticker].to_s.upcase != @distribution.ticker
          @distribution.errors.add(:ticker, :immutable)
          return render_validation_errors(@distribution)
        end

        save(@distribution, :ok)
      end

      def destroy
        @distribution.destroy!
        render json: { data: { deleted_id: @distribution.id } }
      end

      private

      def set_distribution
        @distribution = policy_scope(AssetDistribution).find(params[:id])
        authorize @distribution
      end

      def save(distribution, status)
        distribution.assign_attributes(params.permit(*FIELDS))
        return render_validation_errors(distribution) unless distribution.save

        render json: { data: AssetDistributionBlueprint.render_as_hash(distribution) }, status: status
      end
    end
  end
end
