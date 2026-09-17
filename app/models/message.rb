class Message < ApplicationRecord
  acts_as_tenant(:workspace)

  belongs_to :workspace
  belongs_to :conversation
  has_many_attached :files

  validates :body, presence: true, unless: -> { files.attached? }
  validates :sender_kind, inclusion: { in: %w[staff member] }

  after_create_commit :broadcast!

  def from_staff? = sender_kind == "staff"

  def display_name = sender_name.presence || (from_staff? ? "Spa" : "Khách")

  def image_files = files.select { |f| f.image? }
  def doc_files   = files.reject { |f| f.image? }

  def preview_text
    return body if body.present?
    files.attached? ? "📎 Đã gửi #{files.count} tệp" : ""
  end

  private

  def broadcast!
    broadcast_append_to(
      conversation, target: "messages",
      partial: "shared/message", locals: { message: self }
    )
  rescue => e
    Rails.logger.error("[Message] broadcast failed: #{e.class} #{e.message}")
  end
end
