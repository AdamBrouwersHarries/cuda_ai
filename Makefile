CC=nvcc
CFLAGS=
OUTPUT_PATH=

main:
	nvcc -I/opt/cuda/include/ cuda_tsp.cu -lm -o cuda_tsp