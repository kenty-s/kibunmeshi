namespace :spice_pairings do
  desc "Sync spice pairings in DB from config/spice_pairings.yml"
  task sync: :environment do
    Dish.reload_spice_pairings!
    synced = Dish.sync_spice_pairings!
    puts "Synced spice pairings for #{synced} dishes."
  end

  desc "Sync one dish from config/spice_pairings.yml (usage: bin/rails 'spice_pairings:sync_one[フルーツヨーグルト]')"
  task :sync_one, [ :dish_name ] => :environment do |_task, args|
    dish_name = args[:dish_name].to_s.strip
    abort "Usage: bin/rails 'spice_pairings:sync_one[料理名]'" if dish_name.blank?

    Dish.reload_spice_pairings!
    synced = Dish.sync_spice_pairings!(dish_names: [ dish_name ])

    if synced.zero?
      puts "No rows changed for #{dish_name}."
    else
      puts "Synced spice pairings for #{dish_name}."
    end
  end
end
