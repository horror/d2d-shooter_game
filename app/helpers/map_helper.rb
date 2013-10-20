module MapHelper
  def uploadMap(params)
    find_by_sid(params["sid"])
    check_error(Map.where(name: params["name"]).exists?, "mapExists")

    try_save(Map, {name: params["name"], map: ActiveSupport::JSON.encode(params["map"]), max_players: params["maxPlayers"]})
  end

  def getMaps(params)
    user = find_by_sid(params["sid"])

    maps = Map.all(:select => "id, name, max_players, map", :from => 'maps', :order => 'id').to_a
    maps = maps.map do |line|
      {"id" => line["id"], "name" => line["name"], "maxPlayers" => line["max_players"], "map" => ActiveSupport::JSON.decode(line["map"])}
    end
    ok({maps: maps})
  end
end