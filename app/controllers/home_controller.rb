class HomeController < ApplicationController
  def index
  end

  def binary
      data = [65, 66, 67, 68]
      packed = data.pack 'N*'
      send_data packed
  end

end
