module MarketData
  class CvmFinancials
    BASE_URI = "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/".freeze
    STATEMENTS = %w[DRE BPA BPP DFC_MI DFC_MD].freeze
    SCOPES = %w[con ind].freeze
    LATEST = "ÚLTIMO".freeze
    CENTS_PER_UNIT = { "MIL" => 100_000, "UNIDADE" => 100 }.freeze
    PROFIT = /lucro|preju[ií]zo/i
    PERIOD = /per[ií]odo/i
    EQUITY = /patrim[oô]nio l[ií]quido/i
    LOANS = /empr[eé]stimos e financiamentos/i
    CASH = /caixa e equivalentes|aplica[cç][oõ]es financeiras/i
    DIVIDENDS = /dividend|juros sobre (o )?capital|jcp|proventos/i
    PAID_BY_OTHERS = /n[aã]o.controlador|minorit|recebid/i

    Financial = Data.define(:cnpj, :fiscal_year, :revenue_cents, :net_income_cents, :equity_cents, :net_debt_cents,
      :dividends_paid_cents, :shares_count)
    Account = Data.define(:statement, :code, :description, :cents)

    def self.fetch(year, cnpjs)
      new(year, cnpjs).fetch
    end

    def initialize(year, cnpjs)
      @year = year
      @prefixes = cnpjs.index_by { |cnpj| format_cnpj(cnpj) }
      @accounts = Hash.new { |hash, key| hash[key] = [] }
      @versions = {}
      @shares = {}
      @headers = {}
    end

    def fetch
      found = Download.zip_entry_lines(URI.join(BASE_URI, "dfp_cia_aberta_#{@year}.zip"), entries) { |name, line| read(name, line) }
      found && @prefixes.values.filter_map { |cnpj| financial(cnpj) }
    end

    private

    def entries
      STATEMENTS.product(SCOPES).map { |statement, scope| "dfp_cia_aberta_#{statement}_#{scope}_#{@year}.csv" } << capital_entry
    end

    def capital_entry = "dfp_cia_aberta_composicao_capital_#{@year}.csv"

    def read(name, line)
      return @headers[name] = fields(line) unless @headers.key?(name)

      cnpj = @prefixes[line[0, 18]]
      return unless cnpj

      row = @headers[name].zip(fields(line)).to_h
      name == capital_entry ? add_shares(cnpj, row) : add_account(cnpj, name, row)
    end

    def fields(line)
      line.dup.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8).chomp.split(";", -1)
    end

    def add_account(cnpj, name, row)
      return unless row["ORDEM_EXERC"] == LATEST && CENTS_PER_UNIT.key?(row["ESCALA_MOEDA"])

      _, statement, scope = name.match(/dfp_cia_aberta_(.+)_(con|ind)_/).to_a
      key = [ cnpj, scope ]
      return unless latest_version?(key, statement, row["VERSAO"].to_i)

      cents = (BigDecimal(row["VL_CONTA"]) * CENTS_PER_UNIT.fetch(row["ESCALA_MOEDA"])).round
      @accounts[key] << Account.new(statement: statement, code: row["CD_CONTA"], description: row["DS_CONTA"], cents: cents)
    end

    def latest_version?(key, statement, version)
      current = @versions[[ *key, statement ]]
      return false if current && version < current

      @accounts[key].reject! { |account| account.statement == statement } if current && version > current
      @versions[[ *key, statement ]] = version
    end

    def add_shares(cnpj, row)
      shares = row["QT_ACAO_TOTAL_CAP_INTEGR"].to_i - row["QT_ACAO_TOTAL_TESOURO"].to_i
      version = row["VERSAO"].to_i
      return if shares <= 0 || (@shares[cnpj] && @shares[cnpj].last > version)

      @shares[cnpj] = [ shares, version ]
    end

    def financial(cnpj)
      accounts = scope_accounts(cnpj)
      revenue = find(accounts, "DRE", /\A3\.01\z/)&.cents
      net_income = accounts.select { |account| account.statement == "DRE" && account.code.match?(/\A3\.\d{2}\z/) &&
        account.description.match?(PROFIT) && account.description.match?(PERIOD) }.last&.cents
      equity = find(accounts, "BPP", /\A2\.\d{2}\z/, EQUITY)&.cents
      return unless revenue && net_income && equity

      Financial.new(cnpj: cnpj, fiscal_year: @year, revenue_cents: revenue, net_income_cents: net_income, equity_cents: equity,
        net_debt_cents: net_debt(accounts), dividends_paid_cents: dividends_paid(accounts), shares_count: @shares[cnpj]&.first)
    end

    def scope_accounts(cnpj)
      consolidated = @accounts.fetch([ cnpj, "con" ], [])
      find(consolidated, "BPP", /\A2\.\d{2}\z/, EQUITY) ? consolidated : @accounts.fetch([ cnpj, "ind" ], [])
    end

    def find(accounts, statement, code, description = nil)
      select(accounts, statement, code, description).first
    end

    def select(accounts, statement, code, description = nil)
      accounts.select do |account|
        account.statement.start_with?(statement) && account.code.match?(code) && (description.nil? || account.description.match?(description))
      end
    end

    def net_debt(accounts)
      loans = select(accounts, "BPP", /\A2\.0[12]\.\d{2}\z/, LOANS)
      return if loans.empty?

      loans.sum(&:cents) - select(accounts, "BPA", /\A1\.01\.\d{2}\z/, CASH).sum(&:cents)
    end

    def dividends_paid(accounts)
      return if select(accounts, "DFC", /\A6/).empty?

      select(accounts, "DFC", /\A6\.03\.\d{2}\z/, DIVIDENDS)
        .reject { |account| account.description.match?(PAID_BY_OTHERS) || account.cents.positive? }.sum { |account| -account.cents }
    end

    def format_cnpj(digits)
      "#{digits[0, 2]}.#{digits[2, 3]}.#{digits[5, 3]}/#{digits[8, 4]}-#{digits[12, 2]}"
    end
  end
end
