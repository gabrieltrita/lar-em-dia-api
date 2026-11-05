class AdminMetrics
  WINDOW = 30.days
  WEEKS = 12
  ENGAGED_SERIES = 5

  def to_h
    { users: users, engagement: engagement, signups_by_week: signups_by_week }
  end

  private

  def people
    User.not_anonymized
  end

  def users
    {
      total: people.count,
      confirmed: people.where.not(confirmed_at: nil).count,
      active_30d: people.where(last_sign_in_at: since..).count,
      new_30d: people.where(created_at: since..).count,
      deactivated: people.deactivated.count,
      with_two_factor: people.where.not(otp_enabled_at: nil).count
    }
  end

  def engagement
    {
      with_balance: people.where(id: Balance.select(:user_id)).count,
      with_entries: people.where(id: Entry.select(:user_id)).count,
      with_5_series: people.where(id: EntrySeries.group(:user_id).having("count(*) >= ?", ENGAGED_SERIES).select(:user_id)).count,
      entries_created_30d: Entry.where(created_at: since..).count
    }
  end

  def signups_by_week
    first_week = Date.current.beginning_of_week - (WEEKS - 1).weeks
    counts = people.where(created_at: first_week.beginning_of_day..)
      .group(Arel.sql("date_trunc('week', created_at)::date"))
      .count
    Array.new(WEEKS) do |offset|
      week = first_week + offset.weeks
      { week: week.iso8601, count: counts.fetch(week, 0) }
    end
  end

  def since
    WINDOW.ago
  end
end
