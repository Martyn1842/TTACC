# Duplicates a .bps file containing a Factorio blueprint string as a .json file and vice versa
# json -> bps:
#   compress with zlib deflate compression level 9
#   encode with base64
#   prepend with version byte (currently 0)


import sys
import zlib
import base64
import json


path = sys.argv[0]
path = path[0:-len(path.split("/")[-1])]
start_file = "error"
if len(sys.argv) > 1:
    start_file = path + sys.argv[1]
    end_file = path + sys.argv[1].split(".")[0]


if start_file.endswith(".bps"):
    with open(start_file, "rb") as sf:
        # read file, strip version byte, decode, decompress
        s = zlib.decompress( base64.b64decode( sf.read()[1:] ) )
        if len(sys.argv) > 2 and sys.argv[2] == "-c":
            s = str(s)[2:-1] # just convert to string
        else:
            s = json.dumps(json.loads(s), indent=4) # make the result pretty
        with open(end_file+".json", "w") as ef:
            ef.write(s)

elif start_file.endswith(".json"):
    with open(start_file, "rb") as sf:
        # read file, compress, encode, prepend version byte
        s = b"0"+base64.b64encode( zlib.compress(sf.read(), 9) )
        with open(end_file+".bps", "wb") as ef:
            ef.write(s)

else:
    print("Invalid target file")
    print("Usage: "+sys.argv[0]+""" [target file] [-c]
       target file: the initial file (and relative position) to operate on
       -c         : produce compact output, ie. not formatted for readability""")