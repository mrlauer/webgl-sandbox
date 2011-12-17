class HomeController < ApplicationController
  def index
  end

  def binary
      data = [65, 66, 67, 68]
      packed = data.map { | d | [d].pack 'N' }.join ""
      send_data packed
  end

end
