from random import randrange
alphabet = ['A','C','G','T']
read_count = 2
read_length = 9
for i in range(read_count):
    read = ""
    for j in range(read_length):
        read += alphabet[randrange(4)]
    print(read)
