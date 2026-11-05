class ProjectionSimulation
  include ActiveModel::Validations

  MAX_ENTRIES = 10
  ENTRY_FIELDS = %i[category_id nature description amount_cents due_on].freeze

  attr_reader :entries

  def initialize(user:, inputs:)
    @user = user
    @inputs = inputs
    @entries = []
  end

  def call
    return add_error(:blank) if @inputs.empty?
    return add_error(:too_long, count: MAX_ENTRIES) if @inputs.size > MAX_ENTRIES

    @inputs.each_with_index { |input, index| simulate(input, index) }
    errors.empty?
  end

  private

  def simulate(input, index)
    record, entries = input[:entries_count].present? ? series(input) : single(input)
    return @entries.concat(entries) if entries

    record.errors.each { |error| errors.import(error, attribute: "entries.#{index}.#{error.attribute}") }
  end

  def single(input)
    entry = @user.entries.new(input.slice(*ENTRY_FIELDS))
    [ entry, entry.valid? && [ entry ] ]
  end

  def series(input)
    creator = EntrySeriesCreator.new(
      user: @user,
      attributes: input.slice(*ENTRY_FIELDS),
      count: input[:entries_count],
      direction: input[:direction],
      kind: input[:kind],
      total_cents: input[:total_cents]
    )
    [ creator.series, creator.build ]
  end

  def add_error(type, **options)
    errors.add(:entries, type, **options)
    false
  end
end
