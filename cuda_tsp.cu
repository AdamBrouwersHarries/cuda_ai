#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include "utility.h"
#include <curand_kernel.h>


void random_initialise_state_list(int* state_list, int city_count, int state_count)
{
	for(int i = 0;i<state_count;i++)
	{
		//get the current state (pointer to the start of the state)
		int* state = &(state_list[i*city_count]);
		//initialise the state (guaranteed to be a correct tour)
		for(int j = 0;j<city_count;j++)
		{
			state[j] = j;
		}
		//uses fisher-yates shuffle
		//from: http://stackoverflow.com/a/375407
		//and: http://en.wikipedia.org/wiki/Fisher-Yates_shuffle
		int n = city_count;
		while(n>1)
		{
			int k = rand()%n;
			n--;
			int temp = state[n];
			state[n] = state[k];
			state[k] = temp;
		}	
	}
}
/*
 * prints a state in the format:
 * length : city order
 */
void print_state(int* s, int l, int city_count)
{
	printf("Length %7d :", l);
	int i = 0;
	for(i = 0;i<city_count;i++)
	{
		printf("%2d,",s[i]);
	}
	printf("\b\n");
}
/*
 * Gets the cost of an int* state using distances*
 */
int get_state_cost(int* state, int* distances, int city_count)
{
	int cost = 0;
	for(int i = 0;i<city_count;i++)
	{
		cost = cost + distances[XYW2D(state[i], state[(i+1)%city_count], city_count)];
	}
	return cost;
}
/*void print_stewart_state(state* s, int city_count)
{
	printf("TOURSIZE = %d,\n",city_count);
	printf("LENGTH = %d,\n", s->length);
	int i = 0;
	for(i = 0;i<city_count;i++)
	{
		printf("%d",(s->city_order[i])+1);
		if(i<city_count-1)
		{
			printf(",");
		}
	}
	printf("\n");
}*/
__global__ void sim_anneal(int* a_memory, int* b_memory, int* best_states, int* distances, int city_count, int iterations, curandState *globalRandState)
{
	int s_id = (blockIdx.x*blockDim.x) + threadIdx.x;
	
	//set up memory to hold states and lengths of states
	int *current_state, *next_state, *best_state, current_cost, next_cost, best_cost;
	//define them
	current_state = &(a_memory[s_id*city_count]);
	next_state = &(b_memory[s_id*city_count]);
	best_state = &(best_states[s_id*city_count]);
	//copy input state into current_state to initialise and into best_state[i*city_count]
	for(int i=0;i<city_count;i++)
	{
		best_state[i] = current_state[i];
	}
	//get the cost of the initial state, and therefore the current best_length
	current_cost = 0;
	for(int i = 0;i<city_count;i++)
	{
		current_cost = current_cost + distances[XYW2D(current_state[i], current_state[(i+1)%city_count], city_count)];
	}
	best_cost = current_cost;
	float t;//current temperature
	int k = iterations; int kmax = iterations;
	for(int i = 0;i<iterations;i++)
	{
		t = ((float)(k))/((float)(kmax));
		//first reverse a subset of the current state into the next state
		//get the start and end of the subset
		int start = (int)(curand_uniform(&(globalRandState[s_id]))*(float)(city_count-1)); //start in range 0->(city_count-2)
		int end = start+(int)(curand_uniform(&(globalRandState[s_id]))*(float)(city_count-start)); //end in range start->(city_count-1)
		//copy in data before reversed section
		for(int i = 0;i<start;i++)
		{
			next_state[i] = current_state[i];
		}
		//copy in data after reversed section
		for(int i = end+1;i<city_count;i++)
		{
			next_state[i] = current_state[i];
		}
		//reverse copy section		
		for(;start<=end;start++,end--)
		{
			next_state[start] = current_state[end];
			next_state[end] = current_state[start];
		}
		//get the length of the new state we've made
		next_cost = 0;
		for(int i = 0;i<city_count;i++)
		{
			next_cost = next_cost + distances[XYW2D(next_state[i], next_state[(i+1)%city_count], city_count)];
		}
		//switch them if the new node is shorter
		if(next_cost<current_cost)
		{
			//but first check to see if it's the best we've found
			if(next_cost<best_cost)
			{
				//if it is, assign the costs, and copy the state over
				best_cost = next_cost;
				//however as we're only doing hill climbing for now - leave it commented for efficency
				for(int i= 0;i<city_count;i++)
				{
					best_state[i]=next_state[i];				
				}
			}
			//swap the pointers
			int *temp_ptr = current_state;
			current_state = next_state;
			next_state = temp_ptr;
			//swap the costs (don't need to put the cur into next, will be recalculated)
			current_cost = next_cost;
		}else{
			//check to see what the temperature says, and weather we'll copy anyway
			float rn = curand_uniform(&(globalRandState[s_id]));
			float acc_prob = 1/exp(abs(current_cost-next_cost)/t);
			if(rn>acc_prob)
			{
				//swap anyway
				//swap the pointers
				int *temp_ptr = current_state;
				current_state = next_state;
				next_state = temp_ptr;
				//swap the costs (don't need to put the cur into next, will be recalculated)
				current_cost = next_cost;
			}
		}	
	}
}
__global__ void setup_kernel_randomness(curandState * state, unsigned long seed)
{
	int s_id = (blockIdx.x*blockDim.x) + threadIdx.x;
	curand_init(seed*s_id, s_id, 0, &state[s_id]);
}

int main(int argc, char** argv)
{
	printf("Format: cuda_tsp <infile> <iterations> <blockCount> <threadCount>\n");
	int iterations = atoi(argv[2]);
	int blockCount = atoi(argv[3]);
	int threadCount = atoi(argv[4]);
	printf("Iterations: %d\nblockCount: %d\nthreadCount: %d\n", iterations, blockCount, threadCount);
	printf("Started\n");
	/* set up citygraph stuff */
	srand(time(NULL));
	//read in the file to a c_string
	char* file_data = file_to_cstring(argv[1]);
	//printf("data in the file:\n%s",file_data);
	//create a char** array to hold the tokens in the string
	char** token_array = 0;
	//split the string into tokens, get the number of tokens
	cstring_to_token_array(file_data,",\r\n= ",&token_array);
	printf("Read token array\n");
	//get the city distances
	int* h_city_distances;
	int city_count = token_array_to_graph(token_array, &h_city_distances);
	printf("Created graph\n");
	//allocate device space for city distances
	int* d_city_distances;
	cudaMalloc(&d_city_distances, city_count*city_count*sizeof(int));
	//copy city distances to the device
	cudaMemcpy(d_city_distances, h_city_distances, city_count*city_count*sizeof(int), cudaMemcpyHostToDevice);
	/*sort out memory and stuff*/
	int state_count = blockCount*threadCount;
	//initialise list of states to copy to the cuda memory
	int *h_state_list, *d_a_mem, *d_b_mem, *d_best_states;
	//initialise host space for states
	h_state_list = (int*)malloc(state_count*city_count*sizeof(int));
	//initialise device space for states
	cudaMalloc(&d_a_mem, state_count*city_count*sizeof(int));
	cudaMalloc(&d_b_mem, state_count*city_count*sizeof(int));
	cudaMalloc(&d_best_states, state_count*city_count*sizeof(int));
	printf("All space allocated\n");
	//set up initial values for states
	random_initialise_state_list(h_state_list, city_count, state_count);
	printf("States initialised\n");
	//copy initialised states to device (dst, src)
	cudaMemcpy(d_a_mem, h_state_list, state_count*city_count*sizeof(int), cudaMemcpyHostToDevice);
	
	printf("Starting CUDA code\n");
	//before sim_annealing, set up the random numbers
	curandState* devStates;
	cudaMalloc(&devStates, state_count*sizeof(curandState));
	setup_kernel_randomness<<<(state_count+255)/256, 256>>>(devStates, time(NULL));
	sim_anneal<<<blockCount, threadCount>>>(d_a_mem, d_b_mem, d_best_states, d_city_distances, city_count, iterations, devStates);
	printf("Finished\n");
	//copy the calculated states back
	cudaMemcpy(h_state_list, d_best_states, state_count*city_count*sizeof(int), cudaMemcpyDeviceToHost);
	//iterate over the list of calculated states, and find the best - serial
	int* current_best_state;
	int best_length = INT_MAX;
	for(int i = 0;i<state_count;i++)
	{
		int* current_state = &(h_state_list[i*city_count]);
		int new_length = get_state_cost(current_state, h_city_distances, city_count);
		//print_state(current_state, new_length, city_count);
		//check if better, etc...
		if(new_length < best_length)
		{
			printf("LF: %8d\n", new_length);
			current_best_state = current_state;
			best_length = new_length;
		}
	}
	printf("best state = ");print_state(current_best_state, best_length, city_count);
}