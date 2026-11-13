module Api
  module V1
    class AssetsController < ApplicationController
      include Paginatable

      DISTRIBUTION_MONTHS = 24
      SCREENER_ERRORS = {
        "invalid_filter" => "Indicator filters must be integers",
        "invalid_sort" => "sort must be an indicator or ticker and direction asc or desc"
      }.freeze

      def index
        authorize Asset
        assets = policy_scope(Asset).listed.ordered
        assets = assets.where(asset_type: params[:asset_type]) if Asset.asset_types.key?(params[:asset_type])
        assets = assets.where(sector: params[:sector]) if params[:sector].present?
        assets = assets.search(params[:q]) if params[:q].present?
        screener = AssetScreener.new(params)
        assets = screener.apply(assets)
        return render_error(status: :bad_request, code: screener.error, message: SCREENER_ERRORS.fetch(screener.error)) unless assets

        pagy, assets = pagy(assets)
        render json: { data: AssetBlueprint.render_as_hash(assets), meta: pagination_meta(pagy) }
      end

      def show
        asset = policy_scope(Asset).find_by!(ticker: params[:ticker].to_s.upcase)
        authorize asset
        distributions = asset.distributions.visible_to(current_user).newest_first.where(record_on: (Date.current << DISTRIBUTION_MONTHS)..)
        render json: {
          data: AssetBlueprint.render_as_hash(asset, view: :detail).merge(distributions: AssetDistributionBlueprint.render_as_hash(distributions))
        }
      end
    end
  end
end
