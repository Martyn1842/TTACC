absolute = True

characters = (
    ('a','b','c','d','e','f'),      #0
    ('b','c'),                      #1
    ('a','b','d','e','g'),          #2
    ('a','b','c','d','g'),          #3
    ('b','c','f','g'),              #4
    ('a','c','d','f','g'),          #5
    ('a','c','d','e','f','g'),      #6
    ('a','b','c'),                  #7
    ('a','b','c','d','e','f','g'),  #8
    ('a','b','c','f','g'),          #9
    ('a','b','c','e','f','g'),      #A
    ('c','d','e','f','g'),          #B
    ('a','d','e','f'),              #C
    ('b','c','d','e','g'),          #D
    ('a','d','e','f','g'),          #E
    ('a','e','f','g')               #F
)
# -15 -> 1
signals = {'a':0, 'b':0, 'c':0, 'd':0, 'e':0, 'f':0, 'g':0}

for char in range(len(characters)): #need the index
    char_bit = 0
    if char != 0: #don't set bit for negative zero
        char_bit = 1 << (char+16) if absolute else 1 << (32-char)
    char_bit |= (1 << char)
    char_n = char + 48 if char < 10 else char + 55
    #print( "{:}: {:032b}".format(chr(char_n), char_bit) )
    for segment in characters[char]:
        signals[segment] |= char_bit

# signals['g'] = signals['g'] | (1 << 16) #use 'negtive zero' bit for negtive sign

for segment in signals:
    # wrap into int_32 range
    signals[segment] &= 0xFFFFFFFF
    signals[segment] = signals[segment] - 0x100000000 if signals[segment] >> 31 else signals[segment]
    #print('{:032b}'.format(signals[segment]))
    print(segment+": "+str(signals[segment]))