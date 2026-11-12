require "rails_helper"

RSpec.describe AssetQuote do
  subject { build(:asset_quote) }

  it { is_expected.to belong_to(:asset) }
  it { is_expected.to validate_presence_of(:quoted_on) }
  it { is_expected.to validate_uniqueness_of(:quoted_on).scoped_to(:asset_id) }
  it { is_expected.to validate_numericality_of(:close_cents).only_integer.is_greater_than(0) }
  it { is_expected.to validate_numericality_of(:volume_cents).only_integer.is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_numericality_of(:trades_count).only_integer.is_greater_than_or_equal_to(0) }
end
