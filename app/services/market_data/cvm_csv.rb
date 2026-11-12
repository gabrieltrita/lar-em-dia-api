module MarketData
  module CvmCsv
    def self.parse(content)
      utf8 = content.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8)
      CSV.parse(utf8, col_sep: ";", headers: true, liberal_parsing: true)
    end

    def self.text(value)
      value.to_s.squish.truncate(Asset::NAME_LIMIT, omission: "").presence
    end
  end
end
