# CA2019-FP3
Base Code for Final Project Part-3

# Compile using:
nvcc FMIndex.cu -o FMIndex

# Generate input file:
python generator.py >> small.txt

# Run using:
./FMIndex small.txt

# Array that you need to fill and where final results should be stored:
fourbit_sorted_suffixes_student

# Correctness check
checker() will be used to compare the default and the values calculated by you.
100% correctness should be ensured before submission.

# Note:
You can currently use small.txt as input file, but this can change during tests.

Length of each read will be fixed to 63 for tests also, so you can customize your CUDA kernels and shared memory according to it.

You can use generator.py as below to generate your own smaller or larger datasets as below:

python generator.py >> small.txt
