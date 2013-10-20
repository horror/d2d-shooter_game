module MapHelper
  def uploadMap(params)
    user = find_by_sid(params["sid"])
    check_error(Map.where(name: params["name"]).exists?, "mapExists")

    try_save(Map, {name: params["name"]})
  end

  def getMaps(params)
    user = find_by_sid(params["sid"])

    maps = Map.all(:select => "m.id, m.name", :from => 'maps m', :order => 'm.id').to_a
    ok({maps: maps})
  end
end