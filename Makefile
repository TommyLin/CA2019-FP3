all:
	nvcc FMIndex.cu -o FMIndex

run:
	./FMIndex small.txt

clean:
	@rm -fv FMIndex
