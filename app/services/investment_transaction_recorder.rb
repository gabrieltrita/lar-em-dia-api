class InvestmentTransactionRecorder
  FIELDS = %i[kind traded_on quantity price_cents fees_cents].freeze
  ENTRY_CATEGORIES = { "buy" => "investment_contribution", "sell" => "investment_redemption" }.freeze

  attr_reader :record, :error_code

  def initialize(user, record = nil)
    @user = user
    @record = record || user.investment_transactions.new
  end

  def create(params)
    record.position = position_for(params[:ticker], params[:goal])
    save(params)
  end

  def update(params)
    return save(params) unless params.key?(:ticker) && params[:ticker].to_s.upcase != record.position.ticker

    record.errors.add(:ticker, :immutable)
    false
  end

  def destroy
    others = record.position.transactions.where.not(id: record.id).to_a
    return refuse("insufficient_quantity") if PositionLedger.new(others).shortfall?

    InvestmentTransaction.transaction do
      entry = record.entry
      record.destroy!
      entry&.destroy!
      record.position.destroy! if others.empty?
    end
    true
  end

  private

  def position_for(ticker, goal)
    asset = Asset.find_by(ticker: ticker.to_s.upcase)
    return unless asset

    @user.investment_positions.find_or_initialize_by(asset: asset).tap do |position|
      position.goal = goal if position.new_record? && goal.present?
    end
  end

  def save(params)
    record.assign_attributes(params.slice(*FIELDS))
    record.debit_balance = params.fetch(:debit_balance) { record.entry.present? }
    return false unless record.valid?

    InvestmentTransaction.transaction do
      record.position.save!
      sync_entry
      record.save!
    end
    true
  end

  def sync_entry
    return remove_entry unless record.debit_balance

    entry = record.entry || @user.entries.new
    entry.update!(
      category: Category.find_by!(key: ENTRY_CATEGORIES.fetch(record.kind)), nature: nil, description: "#{record.position.ticker} × #{record.quantity}",
      amount_cents: record.amount_cents, due_on: record.traded_on, status: :paid, paid_on: record.traded_on
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
