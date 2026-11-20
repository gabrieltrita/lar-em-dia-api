class AllocationRecorder
  CATEGORY_KEY = "surplus_allocation"

  attr_reader :record, :error_code

  def initialize(user, record = nil)
    @user = user
    @record = record || user.allocations.new
  end

  def create(target_id:, month:, amount_cents: nil)
    record.assign_attributes(target: @user.allocation_targets.find_by(id: target_id.to_s), month: month)
    record.amount_cents = amount_cents.presence || default_amount
    return false unless record.valid?

    Allocation.transaction do
      record.entry = record.target.reserve_account ? reserve_entry : plain_entry
      record.save!
    end
    true
  end

  def destroy
    movement = record.entry.reserve_movement
    return destroy_movement(movement) if movement

    record.entry.destroy!
    true
  end

  private

  def default_amount
    AllocationPlan.new(user: @user, month: record.month).planned_cents_for(record.target) if record.target && record.month
  end

  def plain_entry
    @user.entries.create!(
      category: Category.find_by!(key: CATEGORY_KEY), description: record.target.name,
      amount_cents: record.amount_cents, due_on: record.used_on, status: :paid, paid_on: record.used_on
    )
  end

  def reserve_entry
    recorder = ReserveMovementRecorder.new(@user)
    recorder.create(account_id: record.target.reserve_account_id, kind: "deposit", moved_on: record.used_on,
      amount_cents: record.amount_cents, debit_balance: true)
    recorder.record.entry
  end

  def destroy_movement(movement)
    recorder = ReserveMovementRecorder.new(@user, movement)
    return true if recorder.destroy

    @error_code = recorder.error_code
    false
  end
end
