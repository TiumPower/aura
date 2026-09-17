namespace :estate do
  desc "Định vị (geocode) các toà nhà chưa có toạ độ — chạy sau khi deploy tính năng bản đồ"
  task geocode_buildings: :environment do
    scope = ActsAsTenant.without_tenant { Building.where(latitude: nil).to_a }
    puts "#{scope.size} toà nhà chưa có toạ độ."
    ok = 0
    scope.each do |building|
      ActsAsTenant.with_tenant(building.workspace) do
        if building.geocode!
          building.reload
          ok += 1
          puts "  ✓ #{building.name} → #{building.latitude},#{building.longitude} [#{building.geocode_precision}]"
        else
          puts "  ✗ #{building.name} — #{building.full_address.presence || 'chưa có địa chỉ'}"
        end
      end
    end
    puts "Xong: #{ok}/#{scope.size} toà nhà đã có vị trí trên bản đồ."
  end
end
