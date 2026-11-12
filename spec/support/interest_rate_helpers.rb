module InterestRateHelpers
  def interest_rate_file(code)
    file_fixture("interest_rates/sgs_#{code}.json").read
  end

  def stub_bcb_series
    InterestRates::Bcb::SERIES.each_value do |code|
      stub_request(:get, %r{\Ahttps://api\.bcb\.gov\.br/dados/serie/bcdata\.sgs\.#{code}/dados\?})
        .to_return(body: interest_rate_file(code), headers: { "Content-Type" => "application/json" })
    end
  end

  def load_interest_rates
    stub_bcb_series
    InterestRates::Sync.call(from: Date.new(2026, 10, 1), to: Date.new(2026, 11, 12))
  end

  def daily_rates(series, dates, rate_e8)
    now = Time.current
    InterestRate.insert_all(dates.map { |date| { series: series, rate_on: date, rate_e8: rate_e8, created_at: now, updated_at: now } })
  end
end

RSpec.configure { |config| config.include InterestRateHelpers }
