class EntryScope
  SCOPES = %w[one following all].freeze
  SHARED_FIELDS = %w[category_id nature description amount_cents].freeze
  SINGLE_ENTRY_FIELDS = %w[status paid_on].freeze

  attr_reader :error_code, :invalid_entry

  def initialize(entry, scope)
    @entry = entry
    @scope = entry.series && SCOPES.include?(scope) ? scope : "one"
  end

  def update(attributes)
    attributes = attributes.to_h.stringify_keys
    return save_single(attributes) if single?

    @error_code = rejection(attributes)
    return false if @error_code

    Entry.transaction do
      saved = entries.all? { |entry| apply(entry, attributes) }
      raise ActiveRecord::Rollback unless saved
    end
    @invalid_entry.nil?
  end

  def destroy
    series = @entry.series
    Entry.transaction do
      next series.destroy! if @scope == "all"

      @scope == "following" ? entries.destroy_all : @entry.destroy!
      refresh(series) if series
    end
  end

  private

  def single?
    @scope == "one"
  end

  def save_single(attributes)
    return true if @entry.update(attributes)

    @invalid_entry = @entry
    false
  end

  def rejection(attributes)
    return "only_for_single_entry" if SINGLE_ENTRY_FIELDS.any? { |field| changes?(attributes, field) }

    "installment_amount_locked" if @entry.series.installments? && changes?(attributes, "amount_cents")
  end

  def changes?(attributes, field)
    attributes.key?(field) && Entry.type_for_attribute(field).cast(attributes[field]) != @entry.public_send(field)
  end

  def entries
    scoped = @entry.series.entries
    @scope == "following" ? scoped.where(series_position: @entry.series_position..) : scoped
  end

  def apply(entry, attributes)
    entry.assign_attributes(attributes.slice(*SHARED_FIELDS))
    entry.due_on = shifted_due_on(entry, attributes["due_on"]) if attributes.key?("due_on")
    return true if entry.save

    @invalid_entry = entry
    false
  end

  def shifted_due_on(entry, value)
    due_on = ActiveModel::Type::Date.new.cast(value)
    due_on && (due_on >> ((entry.series_position - @entry.series_position) * @entry.series.interval_months))
  end

  def refresh(series)
    remaining = series.entries.reload
    return series.destroy! if remaining.empty?
    return if @scope == "one"

    series.update!(entries_count: remaining.size, total_cents: series.installments? ? remaining.sum(&:amount_cents) : nil)
  end
end
