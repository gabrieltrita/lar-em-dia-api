class EntrySeriesCreator
  attr_reader :series

  def initialize(user:, attributes:, count:, direction:, kind: nil, total_cents: nil)
    @user = user
    @attributes = attributes
    @series = user.entry_series.new(kind: kind.presence || "recurring", entries_count: count, direction: direction, total_cents: total_cents)
    @series.direction = "forward" if @series.installments?
  end

  def call
    base = @user.entries.new(@attributes)
    base.amount_cents = nil if @series.installments?
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
    base.amount_cents = @series.installment_amounts.first if @series.installments? && series_valid
    base_valid = base.valid?
    @series.errors.add(:kind, :only_for_expenses) if @series.installments? && base.income?
    return true if base_valid && @series.errors.empty?

    merge_entry_errors(base)
    false
  end

  def merge_entry_errors(base)
    base.errors.each do |error|
      next if @series.installments? && error.attribute == :amount_cents

      @series.errors.import(error)
    end
  end

  def due_dates(due_on)
    offsets = (0...@series.entries_count).to_a
    dates = offsets.map { |offset| @series.direction == "forward" ? due_on >> offset : due_on << offset }
    dates.sort
  end

  def create_entry(base, due_on, position)
    entry = base.dup
    entry.assign_attributes(due_on: due_on, series: @series, series_position: position)
    entry.amount_cents = @series.installment_amounts[position - 1] if @series.installments?
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
