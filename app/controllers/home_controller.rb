require "base64"

class HomeController < ApplicationController
  def basedir
    return File::join ENV['HOME'], "Downloads"
  end

  def index
    # How to determine the directory?
    # Hack for now: hardcode it!
    nrrdFiles = Dir.glob '*.nrrd', base: basedir()
    @files = nrrdFiles
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
      sz = 12 
      sz2 = sz / 2
      bits = 12
      m = (1 << bits) - 1
      depth = 64
      depth2 = depth/2
      height = 64
      height2 = height/2
      width = 64
      width2 = width/2
      hdr = """
NRRD0004
type: short
dimension: 3
sizes: #{width} #{height} #{depth}
endian: big
encoding: raw

"""
      data = []
      (0 .. (depth-1)).each do |i|
          (0 .. (height-1)).each do |j|
              (0 .. (width-1)).each do |k|
                  x = Float(i + 0.5 - depth2) / (depth2 - 0.5)
                  y = Float(j + 0.5 - height2) / (height2 - 0.5)
                  z = Float(k + 0.5 - width2) / (width2 - 0.5)
                  val = [1.0 - (x*x + y*y + z*z), 0.0].max
#                   val = Math.sqrt ( [1.0 - (y*y + 2.0*z*z)/x1/x1, 0.0].max )
#                   val = (i % 2 == i % 16) ? 0 : 1
#                   val = ((y > 0) == (z > 0)) ? 1 : 0
                  data.push Integer(val * m)
              end
          end
      end
      send_data (hdr + (data.pack 'n*'))
  end

  def binary3d_file
      bits = 10
      depth = 130
      height = 256
      width = 256

      filename = '/Users/mrlauer/Downloads/mrhead/MR-head.raw'
      data = ''
      File.open filename, "r" do |strm|
        fmt = 'v*'
        r = strm.read
        results = r.unpack fmt
        results = [bits, width, height, depth] + results
        send_data (results.pack 'n*')
      end
  end

  def headData
      response.header['Content-Encoding'] = 'gzip'
      send_file Rails.root.join('data', 'data2.gz'), filename: 'headData.nrrd', type: 'application/nrrd'
  end

  def nrrdData
    filename = File::join basedir(), params[:filename] + ".nrrd"
    send_file filename, filename: filename, type: 'application/nrrd'
  end

end
