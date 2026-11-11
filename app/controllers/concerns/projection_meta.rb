module ProjectionMeta
  extend ActiveSupport::Concern
  include ProjectionPeriod

  private

  def require_projection_meta_period
    return unless params.key?(:projection_from) || params.key?(:projection_months)

    @projection_meta_from = parse_projection_month(params[:projection_from])
    @projection_meta_months = parse_projection_months(params[:projection_months])
    render_projection_period_error(@projection_meta_from, @projection_meta_months, prefix: "projection_")
  end

  def projection_meta
    return {} unless @projection_meta_from

    { projection: projection_json(Projection.new(user: current_user, from: @projection_meta_from, months: @projection_meta_months)) }
  end
end
