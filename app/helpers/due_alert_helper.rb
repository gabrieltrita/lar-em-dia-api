module DueAlertHelper
  def brl(cents)
    number_to_currency(cents.to_d / 100, unit: "R$ ", separator: ",", delimiter: ".", precision: 2)
  end
end
