class PortfolioPolicy < ApplicationPolicy
  def show? = true
  def history? = true
  def income? = true
end
