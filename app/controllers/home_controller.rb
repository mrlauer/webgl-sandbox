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
      data = [bits, sz, sz, 1]
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
      sz = 16 
      sz2 = sz / 2
      bits = 8
      m = (1 << bits) - 1
      depth = 32
      depth2 = depth/2
      height = 32
      height2 = height/2
      width = 32
      width2 = width/2
      data = [bits, height, width, depth]
      (0 .. (depth-1)).each do |i|
          (0 .. (height-1)).each do |j|
              (0 .. (width-1)).each do |k|
                  x = Float(i + 0.5 - depth2) / (depth2 - 0.5)
                  y = Float(j + 0.5 - height2) / (height2 - 0.5)
                  z = Float(k + 0.5 - width2) / (width2 - 0.5)
                  val = Math.sqrt ( [1.0 - x*x - y*y - z*z, 0.0].max )
#                   val = (i % 2 == i % 16) ? 0 : 1
#                   val = ((y > 0) == (z > 0)) ? 1 : 0
                  data.push Integer(val * m)
              end
          end
      end
      send_data (Base64.encode64(data.pack 'n*'))
  end

end
