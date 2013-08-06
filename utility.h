#ifndef UTILITY_H
#define UTILITY_H
#include <stdlib.h>
//define how to get 2d coordinates from a 1d array, width of i
#define XYW2D(x,y,i) (x+(i*y))
/*
 * Read a ascii file into a single c string (char array)
 * 
 * This function dynamically allocates memory, and returns a pointer to it
 * this memory must be freed after use to avoid a memory leak
 * 
 * Arguments:
 * 		filename: the (relative) path of the file to read in
 * Returns:
 * 		A c string containing the data in the file
 * */
char* file_to_cstring(char* filename)
{
	FILE* inFile;
	int c;
	inFile = fopen(filename, "r");
	if(inFile==NULL)
	{
		return NULL;
	}else{
		int buffer_size = 1;
		char* buffer = (char*)malloc(1);
		c = fgetc(inFile);
		while(c!=EOF)
		{
			buffer = (char*)realloc(buffer, ++buffer_size);
			buffer[buffer_size-2] = c;
			c = fgetc(inFile);
		}
		buffer[buffer_size-1] = '\0';
		return buffer; //don't forget to free buffer after use!
	}	
}
/*
 * Takes a string, and returns an array of tokens (c strings) by breaking 
 * the string at any of the delimiter characters. 
 * Ignores/removes delimiter characters
 * 
 * 
 * Arguments:
 * 		data: the string to split
 * 		delimiter: the list of delimiters to split on
 * 		token list: a pointer to an array of c strings, which is populated
 * 					with the tokens split from the original string
 * Returns:
 * 		The number of tokens the string has been split in to.
 * */
int cstring_to_token_array(char* data,char* delimiter,char*** token_list)
{
	char* token_iterator;
	char** output_array = (char**)malloc(sizeof(char*));
	output_array = NULL;
	int index = 1;
	token_iterator = strtok(data,delimiter);
	while(token_iterator!=NULL)
	{
		char* buffer = (char*)calloc(strlen(token_iterator)+1,sizeof(char));
		strcpy(buffer, token_iterator);
		output_array = (char**)realloc(output_array, sizeof(char*)*index);
		output_array[index-1] = buffer;
		index++;
		token_iterator = strtok(NULL, delimiter);		
	}
	*token_list = output_array;
	return index-1;
}
/*
	Transforms an array of strings into a tsp graph (list of distances)
	char** token_array: the array of tokens
	int** a pointer to the 1d array of integers, which will be interpreted as a 2d array
*/
int token_array_to_graph(char** token_array, int** graph)
{
	//token array is in format:
	//[NAME][*name*][SIZE][*size*][*dist*][*dist*]...[*dist*]
	int city_count = atoi(token_array[3]);
	int* temp_graph = (int*)calloc(city_count*city_count,sizeof(int));
	//now loop over the values in the tokens, and add them to the temp graph
	int i,j;
	int index = 4;
	for(i = 0;i<city_count;i++)
	{	
		for(j = i+1;j<city_count;j++)
		{
			int dist = atoi(token_array[index]);
			temp_graph[XYW2D(i,j,city_count)] = dist;
			temp_graph[XYW2D(j,i,city_count)] = dist;
			index++;
		}
	}
	*graph = temp_graph;
	return city_count;
}

#endif

