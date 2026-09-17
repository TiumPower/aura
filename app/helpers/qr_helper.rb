module QrHelper
  # Renders `data` as a scalable QR SVG. `color` is a hex string without '#'.
  def qr_svg(data, color: "1A1A1A", size: 220)
    qr = RQRCode::QRCode.new(data.to_s, level: :m)
    svg = qr.as_svg(offset: 0, color: color, shape_rendering: "crispEdges",
                    standalone: true, use_path: true, viewbox: true)
    svg.sub("<svg",
      %(<svg width="#{size}" height="#{size}" style="width:#{size}px;height:#{size}px;display:block")
    ).html_safe
  end

  # Renders `data` as a downloadable PNG (binary string). For printable QR codes.
  def qr_png(data, color: "1A1A1A", size: 720)
    qr = RQRCode::QRCode.new(data.to_s, level: :m)
    qr.as_png(size: size, border_modules: 2, fill: ChunkyPNG::Color::WHITE,
              color: ChunkyPNG::Color.from_hex("##{color}")).to_blob
  end
end
