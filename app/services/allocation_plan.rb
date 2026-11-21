class AllocationPlan
  attr_reader :month

  def initialize(user:, month:)
    @user = user
    @month = month.beginning_of_month
  end

  def to_h
    planned = items.sum { |item| item[:amount_cents] }
    {
      month: month.strftime("%Y-%m"),
      closing_cents: closing_cents,
      base_cents: base_cents,
      used_cents: used_cents,
      planned_cents: planned,
      unallocated_cents: base_cents - planned,
      items: items
    }
  end

  def planned_cents_for(target)
    items.find { |item| item[:target_id] == target.id }.fetch(:amount_cents)
  end

  private

  def items
    @items ||= begin
      free = [ [ base_cents, 0 ].max - used_cents, 0 ].max
      planned = pending_targets.reject(&:remainder?).to_h do |target|
        cents = [ wanted_cents(target), free ].min
        free -= cents
        [ target.id, cents ]
      end
      targets.map { |target| item(target, planned.fetch(target.id, free)) }
    end
  end

  def pending_targets
    targets.reject { |target| allocations.key?(target.id) }
  end

  def item(target, planned)
    allocation = allocations[target.id]
    {
      target_id: target.id,
      name: target.name,
      mode: target.mode,
      amount_cents: planned,
      percent_bps: target.percent_bps,
      reserve_account_id: target.reserve_account_id,
      category_id: target.category_id,
      used: false,
      allocation_id: nil,
      used_on: nil
    }.merge(allocation ? used_fields(allocation) : {})
  end

  def used_fields(allocation)
    { amount_cents: allocation.entry.amount_cents, used: true, allocation_id: allocation.id, used_on: allocation.entry.due_on.iso8601 }
  end

  def wanted_cents(target)
    target.fixed? ? target.amount_cents : [ base_cents, 0 ].max * target.percent_bps / AllocationTarget::MAX_PERCENT_BPS
  end

  def targets
    @targets ||= @user.allocation_targets.ordered.to_a
  end

  def allocations
    @allocations ||= @user.allocations.includes(:entry).where(month: month).index_by(&:target_id)
  end

  def used_cents
    @used_cents ||= allocations.values.sum { |allocation| allocation.entry.amount_cents }
  end

  def closing_cents
    @closing_cents ||= Projection.new(user: @user, from: month, months: 1).months.first[:closing_cents]
  end

  def base_cents
    closing_cents + used_cents
  end
end
