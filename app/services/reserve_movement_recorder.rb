class ReserveMovementRecorder
  FIELDS = %i[kind moved_on amount_cents].freeze
  ENTRY_CATEGORIES = { "deposit" => "reserve_deposit", "withdrawal" => "reserve_withdrawal" }.freeze

  attr_reader :record, :error_code

  def initialize(user, record = nil)
    @user = user
    @record = record || user.reserve_movements.new
  end

  def create(params)
    record.account = @user.reserve_accounts.find_by(id: params[:account_id].to_s)
    save(params)
  end

  def update(params)
    return save(params) unless params.key?(:account_id) && params[:account_id].to_s != record.account_id

    record.errors.add(:account_id, :immutable)
    false
  end

  def destroy
    others = record.account.movements.where.not(id: record.id).to_a
    return refuse("insufficient_reserve") if ReserveLedger.for(record.account, others).shortfall?

    ReserveMovement.transaction do
      entry = record.entry
      record.destroy!
      entry&.destroy!
    end
    true
  end

  private

  def save(params)
    record.assign_attributes(params.slice(*FIELDS))
    record.debit_balance = params.fetch(:debit_balance) { record.entry.present? }
    return false unless record.valid?

    ReserveMovement.transaction do
      sync_entry
      record.save!
    end
    true
  end

  def sync_entry
    return remove_entry unless record.debit_balance

    entry = record.entry || @user.entries.new
    entry.update!(
      category: Category.find_by!(key: ENTRY_CATEGORIES.fetch(record.kind)), nature: nil, description: record.account.name,
      amount_cents: record.amount_cents, due_on: record.moved_on, status: :paid, paid_on: record.moved_on
    )
    record.entry = entry
  end

  def remove_entry
    entry = record.entry
    record.entry = nil
    entry&.destroy!
  end

  def refuse(code)
    @error_code = code
    false
  end
end
