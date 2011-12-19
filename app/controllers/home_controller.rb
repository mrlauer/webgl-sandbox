require "base64"

class HomeController < ApplicationController
  def index
  end

  def binary
      data = [65, 66, 67, 68]
      packed = data.pack 'N*'
      send_data packed
  end

  # format returned is 
  #     first byte: zero
  #     second byte: number of bits
  #     bytes 3 and 5: width (big-endian)
  #     bytes 5 and 6: height (big-endian)
  #     everything else: data, in 2-byte words, big-endian
  def binary2d
      sz = 256
      sz2 = sz / 2
      bits = 8
      m = (1 << bits) - 1
      data = [bits, sz, sz]
      (0 .. (sz-1)).each do |i|
          (0 .. (sz-1)).each do |j|
              x = Float(i - sz2) / sz2
              y = Float(j - sz2) / sz2
              val = Math.sqrt ( [1.0 - x*x - y*y, 0.0].max )
              data.push Integer(val * m)
          end
      end
      send_data (Base64.encode64(data.pack 'n*'))
  end

  # format returned is 
  #     first byte: zero
  #     second byte: number of bits
  #     bytes 3 and 5: width (big-endian)
  #     bytes 5 and 6: height (big-endian)
  #     bytes 7 and 8: height (big-endian)
  #     everything else: data, in 2-byte words, big-endian
  def binary3d
      sz = 128
      sz2 = sz / 2
      bits = 8
      m = (1 << bits) - 1
      data = [bits, sz, sz, sz]
      (0 .. (sz-1)).each do |i|
          (0 .. (sz-1)).each do |j|
              (0 .. (sz-1)).each do |k|
                  x = Float(i - sz2) / sz2
                  y = Float(j - sz2) / sz2
                  z = Float(k - sz2) / sz2
                  val = Math.sqrt ( [1.0 - x*x - y*y - k*k, 0.0].max )
                  data.push Integer(val * m)
              end
          end
      end
      send_data (Base64.encode64(data.pack 'n*'))
  end

end
