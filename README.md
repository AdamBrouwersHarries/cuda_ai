##CUDA Ai
Short program using cuda to solve the travelling saleman problem with simulated annealing
Each kernel performs one instance of simulated annealing, and the best is selected at the end.

run using: `cuda_tsp <cityfile> <iterations> <blockCount> <threadCount>`

The city file format is:

	NAME=<cityfilename>,SIZE=<city_count>,
	[city_1 distances, from city_1 to city_2,city_3...city_n, comma seperated],
	[city_2 distances, from city_2 to city_3,city_4...city_n, comma seperated],
	etc

See `utility.h` for an example of parsing a file. 
Unfortunately I cannot provide any example city files here, however contact me at harries.adam[at]gmail.com if you would like one.