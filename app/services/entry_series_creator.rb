class EntrySeriesCreator
  attr_reader :series

  def initialize(user:, attributes:, count:, direction:)
    @user = user
    @attributes = attributes
    @series = user.entry_series.new(entries_count: count, direction: direction)
  end

  def call
    base = @user.entries.new(@attributes)
    return false unless valid?(base)

    EntrySeries.transaction do
      @series.save!
      due_dates(base.due_on).each.with_index(1) { |due_on, position| create_entry(base, due_on, position) }
    end
    true
  end

  private

  def valid?(base)
    series_valid = @series.valid?
    return true if base.valid? && series_valid

    @series.errors.merge!(base.errors)
    false
  end

  def due_dates(due_on)
    offsets = (0...@series.entries_count).to_a
    dates = offsets.map { |offset| @series.direction == "forward" ? due_on >> offset : due_on << offset }
    dates.sort
  end

  def create_entry(base, due_on, position)
    entry = base.dup
    entry.assign_attributes(due_on: due_on, series: @series, series_position: position)
    copy_status(entry, base) unless due_on == base.due_on
    entry.save!
  end

  def copy_status(entry, base)
    paid = base.paid? && due_on_reached?(entry)
    entry.status = paid ? :paid : :pending
    entry.paid_on = paid ? entry.due_on : nil
  end

  def due_on_reached?(entry)
    entry.due_on <= Date.current
  end
end
