class InterestRate < ApplicationRecord
  E8 = 100_000_000

  enum :series, { selic: "selic", cdi: "cdi", savings: "savings", selic_target: "selic_target" }, validate: true

  validates :rate_on, presence: true, uniqueness: { scope: :series }
  validates :rate_e8, numericality: { only_integer: true }

  def self.latest(series)
    where(series: series).order(rate_on: :desc).first
  end

  def self.between(series, range)
    where(series: series, rate_on: range).order(:rate_on).pluck(:rate_on, :rate_e8)
  end

  def fraction
    BigDecimal(rate_e8) / E8
  end
end
