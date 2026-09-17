# Protects records that carry financial history from being destroyed.
#
# Deleting a building used to cascade to its units, their leases and every bill
# — including paid ones — behind nothing but a browser confirm. Money records
# must survive a misclick, so anything with history can only be ARCHIVED:
# hidden from the working lists, fully intact in the database.
module Archivable
  extend ActiveSupport::Concern

  included do
    scope :archived, -> { where.not(archived_at: nil) }
    scope :unarchived, -> { where(archived_at: nil) }

    before_destroy :block_destroy_when_protected, prepend: true
  end

  def archived? = archived_at.present?

  # Archiving hides a record from the working lists, so it must not be possible
  # while the room is still in use — otherwise an occupied room silently
  # disappears from the landlord's view.
  def archive_block_reason = nil

  def archivable? = archive_block_reason.nil?

  # Returns false (with an error on :base) when the record is still in use.
  def archive
    reason = archive_block_reason
    if reason
      errors.add(:base, reason)
      return false
    end
    update(archived_at: Time.current)
  end

  def archive!
    archive || raise(ActiveRecord::RecordInvalid.new(self))
  end

  def unarchive! = update!(archived_at: nil)

  # Why this record can't be deleted, or nil when deletion is safe.
  # Implemented per model.
  def destroy_block_reason = nil

  def destroyable? = destroy_block_reason.nil?

  private

  def block_destroy_when_protected
    reason = destroy_block_reason
    return if reason.nil?
    errors.add(:base, reason)
    throw(:abort)
  end
end
