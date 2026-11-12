class PortfolioPolicy < ApplicationPolicy
  def show? = true
  def history? = true
end
