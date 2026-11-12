class InvestmentPositionPolicy < ApplicationPolicy
  def update? = record.user_id == user.id

  class Scope < Scope
    def resolve
      scope.where(user: user)
    end
  end
end
