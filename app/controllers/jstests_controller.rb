class JstestsController < ApplicationController
    def jstests
    end

    def nrrd
        type = params[:type]
        encoding = params[:encoding]
        width = 5
        height = 5
        depth = 5
        hdr = """NRRD0004
type: #{type}
dimension: 3
sizes: #{width} #{height} #{depth}
endian: little
encoding: #{encoding}

"""
        
        data = (1 .. width*depth*height).to_a
        case type
        when 'signed char', 'int8', 'int8_t'
            fmt = 'c'
        when 'uchar', 'unsigned char', 'unit8', 'uint8_t'
            fmt = 'C'
        when "short", "short int", "signed short", "signed short int", "int16", "int16_t"
            fmt = 's'
        when "ushort", "unsigned short", "unsigned short int", "uint16", "uint16_t"
            fmt = 'v'
        when "int", "signed int", "int32", "int32_t"
            fmt = 'l'
        when "uint", "unsigned int", "uint32", "uint32_t"
            fmt = 'V'
        else
            fmt = 'N'
        end

        fmt += '*'

        payload = data.pack fmt
        if params[:encoding] == "gzip" then
          io = StringIO.new
          gz = Zlib::GzipWriter.new(io)
          gz.write payload
          gz.close
          payload = io.string
        end

        nrrd = hdr + payload

        send_data nrrd, :disposition => 'inline'
    end
end
