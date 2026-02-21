module DishesHelper
  def cookpad_search_url(dish_name)
    query = ERB::Util.url_encode(dish_name.to_s)
    "https://cookpad.com/search/#{query}"
  end

  def tabelog_search_url(dish_name)
    query = ERB::Util.url_encode(dish_name.to_s)
    "https://tabelog.com/rstLst/?sk=#{query}"
  end
end
