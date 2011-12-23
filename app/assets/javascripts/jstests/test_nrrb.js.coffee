#= require readnrrd

module "nrrd reader"

testData = """
NRRD0004
# Complete NRRD file format specification at:
# http://teem.sourceforge.net/nrrd/format.html
type: short
dimension: 3
space: left-posterior-superior
sizes: 256 256 130
space directions: (0,1,0) (0,0,-1) (-1.299995,0,0)
kinds: domain domain domain
endian: little
encoding: raw
space origin: (86.644897,-133.928604,116.785698)
data file: MR-head.raw

foobarbazwox
"""

test "simple nrrd reader", ->
    reader = new NrrdReader testData
    ok(reader?, "nrrd reader created")

    reader.parseHeader()
    equal reader.type, 'short', 'read type'
    equal reader.endian, 'little', 'read endian'
    deepEqual reader.sizes, [256, 256, 130], 'read sizes'
    deepEqual reader.vectors, [ [0, 1, 0], [0, 0, -1], [-1.299995, 0, 0] ]

    equal testData[reader.pos..], 'foobarbazwox', 'data position'
