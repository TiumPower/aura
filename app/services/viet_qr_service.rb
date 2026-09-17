# Builds a VietQR (Napas 247) EMVCo payload string for a bank transfer with a
# preset amount + description, so the tenant just scans and confirms. Render the
# returned string as a QR with the qr_svg / qr_png helpers.
#
# Requires the landlord's bank: acquirer BIN, account number, (account name).
class VietQrService
  GUID = "A000000727"
  SERVICE_TO_ACCOUNT = "QRIBFTTA"

  # A short list of common Vietnamese banks → Napas acquirer BIN.
  BANKS = {
    "vietcombank" => { bin: "970436", name: "Vietcombank" },
    "techcombank" => { bin: "970407", name: "Techcombank" },
    "mbbank"      => { bin: "970422", name: "MB Bank" },
    "vietinbank"  => { bin: "970415", name: "VietinBank" },
    "bidv"        => { bin: "970418", name: "BIDV" },
    "agribank"    => { bin: "970405", name: "Agribank" },
    "acb"         => { bin: "970416", name: "ACB" },
    "vpbank"      => { bin: "970432", name: "VPBank" },
    "tpbank"      => { bin: "970423", name: "TPBank" },
    "sacombank"   => { bin: "970403", name: "Sacombank" },
    "vib"         => { bin: "970441", name: "VIB" },
    "msb"         => { bin: "970426", name: "MSB" }
  }.freeze

  def initialize(bin:, account_no:, amount: nil, description: nil)
    @bin = bin.to_s
    @account_no = account_no.to_s
    @amount = amount
    @description = description.to_s.gsub(/[^\w\s]/, " ").strip
  end

  def self.bank_options = BANKS.map { |k, v| [v[:name], k] }
  def self.bin_for(code) = BANKS.dig(code.to_s, :bin)

  def payload
    consumer = tlv("00", @bin) + tlv("01", @account_no)
    merchant = tlv("00", GUID) + tlv("01", consumer) + tlv("02", SERVICE_TO_ACCOUNT)

    s = +""
    s << tlv("00", "01")                       # payload format
    s << tlv("01", @amount ? "12" : "11")       # dynamic if amount present
    s << tlv("38", merchant)
    s << tlv("53", "704")                       # VND
    s << tlv("54", format_amount(@amount)) if @amount
    s << tlv("58", "VN")
    s << tlv("62", tlv("08", @description[0, 25])) if @description.present?
    s << "6304"
    s << crc16(s)
    s
  end

  private

  def tlv(id, value)
    v = value.to_s
    "#{id}#{format('%02d', v.length)}#{v}"
  end

  def format_amount(amt)
    a = amt.to_i
    a.to_s
  end

  # CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF), uppercase 4-hex.
  def crc16(str)
    crc = 0xFFFF
    str.each_byte do |b|
      crc ^= (b << 8)
      8.times do
        crc = (crc & 0x8000).zero? ? (crc << 1) : ((crc << 1) ^ 0x1021)
        crc &= 0xFFFF
      end
    end
    format("%04X", crc)
  end
end
