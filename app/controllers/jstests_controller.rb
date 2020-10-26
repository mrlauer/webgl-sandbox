class JstestsController < ApplicationController
    include ActionController::Live

    def jstests
    end

    def nrrd
        type = params[:type]
        encoding = params[:encoding]
        width = 3
        height = 4
        depth = 5
        endian = request.query_parameters.fetch "endian", "little"
        hdr = """NRRD0004
type: #{type}
dimension: 3
sizes: #{width} #{height} #{depth}
endian: #{endian}
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

        if "svlV".include? fmt then
          if endian == 'little' then
            fmt += '<'
          else
            fmt += '>'
          end
        end

        fmt += '*'

        response.stream.write hdr

        payload = data.pack fmt
        if params[:encoding] == "gzip" then
          gz = Zlib::GzipWriter.new(response.stream)
          gz.write payload
          gz.close
        else
          response.stream.write payload
        end

    ensure
        response.stream.close
    end
end
