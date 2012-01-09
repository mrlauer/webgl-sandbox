class JstestsController < ApplicationController
    def jstests
    end

    def nrrd
        type = params[:type]
        width = 2
        height = 2
        depth = 2
        hdr = """NRRD0004
type: #{type}
dimension: 3
sizes: #{width} #{height} #{depth}
endian: little
encoding: raw

"""
        
        data = (1 .. 8).to_a
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

        puts "fmt = #{fmt}"

        nrrd = hdr + (data.pack fmt)

        puts "nrrd length #{hdr.length}; nrrd length #{nrrd.length}"

        send_data nrrd, :disposition => 'inline'
    end
end
