module DishesHelper
  def kurashiru_search_url(dish_name)
    query = ERB::Util.url_encode(dish_name.to_s)
    "https://www.kurashiru.com/search?query=#{query}"
  end

  def tabelog_search_url(dish_name)
    query = ERB::Util.url_encode(dish_name.to_s)
    "https://tabelog.com/rstLst/?sk=#{query}"
  end
end
