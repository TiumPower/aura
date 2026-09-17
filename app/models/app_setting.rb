# Platform-level key/value store (not tenant-scoped). Used for rotating Zalo ZNS
# OA tokens, which must persist durably across requests.
class AppSetting < ApplicationRecord
  def self.get(key) = find_by(key: key.to_s)&.value

  def self.set(key, value)
    rec = find_or_initialize_by(key: key.to_s)
    rec.update!(value: value.to_s)
    value
  end
end
