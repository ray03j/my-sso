class Consent < ApplicationRecord
  before_validation :normalize_scope

  validates :user_id, presence: true, uniqueness: { scope: :client_id }
  validates :client_id, presence: true
  validates :scope, presence: true

  def scopes
    scope.to_s.split.map(&:strip).compact_blank
  end

  def includes_scope?(requested_scope)
    scopes.include?(requested_scope)
  end

  def self.record!(user_id:, client_id:, scope:)
    find_or_initialize_by(user_id: user_id, client_id: client_id).tap do |consent|
      consent.scope = scope
      consent.save!
    end
  end

  private

  def normalize_scope
    self.scope = scope.to_s.split.map(&:strip).compact_blank.join(' ')
  end
end
