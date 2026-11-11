module ProjectionPeriod
  MONTH_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/

  private

  def parse_projection_month(value)
    return Date.current.beginning_of_month if value.blank?

    Date.strptime(value.to_s, "%Y-%m") if MONTH_FORMAT.match?(value.to_s)
  end

  def parse_projection_months(value)
    return Projection::DEFAULT_MONTHS if value.blank?
    return Projection::ALL_MONTHS if value.to_s == Projection::ALL_MONTHS.to_s

    number = Integer(value.to_s, 10, exception: false)
    number if Projection::MONTHS_RANGE.cover?(number)
  end

  def render_projection_period_error(from, months, prefix: "")
    return render_error(status: :bad_request, code: "invalid_month", message: "#{prefix}from must be a month (YYYY-MM)") unless from

    render_error(status: :bad_request, code: "invalid_months", message: "#{prefix}months must be an integer from 1 to 60 or all") unless months
  end

  def projection_json(projection)
    { anchor: anchor_json(projection.anchor), months: projection.months, alerts: projection.alerts, last_entry_month: projection.last_entry_month }
  end

  def anchor_json(balance)
    balance && { amount_cents: balance.amount_cents, as_of: balance.as_of.iso8601 }
  end
end
