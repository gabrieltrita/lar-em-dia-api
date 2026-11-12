class ReservePolicy < ApplicationPolicy
  def show? = true
  def update? = true
  def projection? = true
end
