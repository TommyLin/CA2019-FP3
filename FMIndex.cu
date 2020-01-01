#include <iostream>
#include <fstream>
#include <iomanip>
#include <cstring>
#include <cmath>
#include <stdlib.h>
#include <sys/time.h>

using namespace std;

//-----------------------DO NOT CHANGE NAMES, ONLY MODIFY VALUES--------------------------------------------

//Final Value that will be compared for correctness
//You need to create the function prototypes and definitions as per your design, but you need to present final results in this array
//-----------------------------Structures for correctness check-------------------
char **fourbit_sorted_suffixes_student;
int read_count = 0;
int read_length = 0;
int num_value = 0;
char **fourbit_sorted_suffixes_original;
int BLOCKS, THREADS;
char* fourbitEncodeRead(char *read, int length);
char** generateSuffixes(char *read, int byte_length);
char ctable[] = {'$', 'A', 'C', 'G', 'T', '5', '6', '7',
	'8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
	
char **student;

void print_string_2d(char **str, int len){
	printf("=== string address ===\n");
	for (int i = 0; i < len; i++) {
		for(int z = 0; z < len/2 ; z++){
			printf("%p ", &(str[i][z]));
		}
		printf("\n");
	}
	printf("\n");

	printf("================================\n");
	for (int i = 0; i < 2 * len; i++) {
		printf(" %X", i);
	}
	printf("\n============== 2d print ==============\n");

	for (int i = 0; i < len; i++) {
		for (int z = 0; z < len/2; z++){
			printf(" %c %c", ctable[str[i][z]>>4], ctable[str[i][z] &0xF]);
		}
		printf("\n");
	}
}
void print_string_1d(char *str, int len){
	printf("=== string address ===\n");
	cout<<"input string is "<<str<<endl;
	cout<<"lengh = "<<len<<endl;
	cout<<"num_value = "<<num_value<<endl;

	printf("================================\n");
	for (int i = 0; i < 2 * len; i++) {
		printf(" %X", i);
	}
	printf("\n============== 1d print ==============\n");

	for (int i = 0; i < num_value; i++) {
		for (int z = 0; z < len/2; z++){
			printf(" %c %c", ctable[str[(i*len/2+z)]>>4 ], ctable[str[i*len/2+z] &0xF]);
		}		
		printf("\n");
	}
	printf("\n============== 1d print ==============\n");
}


__global__ void bitonic_sort_step(char *dev_values, int j, int k, int num_value, int read_length, int read_count){
    //printf("gfdgfdgdsfg\n");
    int flag = 0;
	unsigned int i, ixj; /* Sorting partners: i and ixj */
    i = threadIdx.x + blockDim.x * blockIdx.x;
    ixj = i^j;
    char temp_char_i,temp_char_ixj;
	printf("input string = %s\n",dev_values);
    /* The threads with the lowest ids sort the array. */
    flag = 0;
    if ((ixj)>i) {
        for(int l=0;l<read_length;l++){
			printf("lower char for i = %c\n",dev_values[i*read_length/2+l]&(0xF));
			printf("higher char for i = %c\n",(dev_values[i*read_length/2+l]&(0xF0))>>4);
			
			printf("lower char for ixj = %c\n",dev_values[ixj*read_length/2+l]&(0xF));
			printf("higher char for ixj = %c\n",(dev_values[ixj*read_length/2+l]&(0xF0))>>4);
			
			if(i%2==0) temp_char_i = dev_values[i*read_length/2+l]&(0xF);
			else if(i%2==1) temp_char_i = dev_values[i*read_length/2+l]>>4;
			if(ixj%2==0) temp_char_ixj = dev_values[ixj*read_length/2+l]&(0xF);
			else if(ixj%2==1) temp_char_ixj = dev_values[ixj*read_length/2+l]>>4;
            printf("compare data:\n%d\t%c\n%d\t%c\n",i,temp_char_i,ixj,temp_char_ixj);
			if(temp_char_i>temp_char_ixj){
                //if(i==0&&i*read_length+l==fir*65 && ixj*read_length+l==sec*65)printf(">>>>>>>>>>>>>>>>>>\n");
				flag = 1;
                break;
            }
            else if(temp_char_i<temp_char_ixj){
                //if(i==0&&i*read_length+l==fir*65 && ixj*read_length+l==sec*65)printf("<<<<<<<<<<<<<<<<<<<<\n");
                flag = -1;
                break;
            }
            //if(i==0&&i*read_length+l==fir*65 && ixj*read_length+l==sec*65)printf("=========================\n");
            flag = 0;

        }
        //printf("i=%d, ixj=%d, sorting result flag = %d\n",i,ixj,flag);


        if ((i&k)==0) {
            // Sort ascending //
            //printf("1110");
            //for(int m=0;m<num_value;m++){

                if (flag==1) {
                    //printf("3333, %d, %d\n", i, ixj);
                    char* temp;
					temp = (char*)malloc(sizeof(char)*read_length/2);
					memcpy(temp, &dev_values[i*read_length/2], read_length/2*sizeof(char));
					memcpy(&dev_values[i*read_length/2], &dev_values[ixj*read_length/2], read_length/2*sizeof(char));
					memcpy(&dev_values[ixj*read_length/2], temp, read_length/2*sizeof(char));
					free(temp);
                }
        }
        if ((i&k)!=0) {
            // Sort descending

            if (flag==-1) {
                //printf("2222, %d, %d\n", i, ixj);
                    char* temp;
					temp = (char*)malloc(sizeof(char)*read_length/2);
					memcpy(temp, &dev_values[i*read_length/2], read_length/2*sizeof(char));
					memcpy(&dev_values[i*read_length/2], &dev_values[ixj*read_length/2], read_length/2*sizeof(char));
					memcpy(&dev_values[ixj*read_length/2], temp, read_length/2*sizeof(char));
					free(temp);
            }
        }
    }
}
void bitonic_sort(char **values){
    char *dev_values;
    size_t size = read_length/2 * sizeof(char);
    char *temp;
    char *temp_char = new char[read_length/2];
    temp = (char*)malloc(num_value*size);
    for(int i=0;i<read_length/2;i++){
        temp_char[i]=0x44;
    }
    for(int i=0;i<num_value;i++){
        if(i<read_length*read_count){
            memcpy(&temp[i*read_length/2],values[i],size);
        }
        else{
            memcpy(&temp[i*read_length/2],temp_char,size);
        }
    }
    cudaMalloc((void**) &dev_values, size*num_value);

    cudaMemcpy(dev_values, temp, num_value*size, cudaMemcpyHostToDevice);

    dim3 blocks(BLOCKS,1);    /* Number of blocks   */
    dim3 threads(THREADS,1);  /* Number of threads  */
	cout<<"=========== before temp ==========="<<endl;
	print_string_1d (temp,read_length*read_count);
	cout<<"=========== after temp ==========="<<endl;
    int j, k;
    /* Major step */

    for (k = 2; k <= 2; k <<= 1) {
        //* Minor step */
        for (j=k>>1; j>0; j=j>>1) {
			bitonic_sort_step<<<blocks, threads>>>(dev_values, j, k, num_value,read_length, read_count);
		}
    }
	
    cudaMemcpy(temp, dev_values, read_length*read_count*size, cudaMemcpyDeviceToHost);
	
	 for(int i=0;i<read_length*read_count;i++){

        memcpy(values[i],&temp[i*read_length/2],read_length/2*sizeof(char));

    }  
	
	
    /*for(int i=0;i<num_value;i++){
        if(i<read_length*read_count){
            memcpy(values[i],&temp[i*read_length],read_length*sizeof(char));
        }
        else{
            memcpy(temp_char,&temp[i*read_length],read_length*sizeof(char));
        }
    }	*/
	print_string_2d(values, read_length);
    //cout<<"begin teeeeeeeeeeeeeeeeeeeeeeeeeeeeeemp"<<endl;


	free(temp);
    cudaFree(dev_values);
}


void pipeline_stu(char **reads, int read_length, int read_count){
	int temp_stu = ceil(log2((float)read_length));
	num_value = pow(2,temp_stu);
	if(num_value<=256){
		THREADS = num_value;
		BLOCKS = 1;
	}
	else{
		THREADS = 256;
		BLOCKS = num_value/THREADS;
	}
    fourbit_sorted_suffixes_student = (char**)malloc(read_length*read_count*sizeof(char*));
    for(int i=0;i<read_count;i++){
        char **suffixes_for_read = generateSuffixes(fourbitEncodeRead(reads[i], read_length), read_length/2);
		cout << "read_length = " << read_length << endl;
		for(int z = 0; z < read_length ; z++){
			//char temp = (z%2==0)?(*suffixes_for_read[z]&0x0f):(*suffixes_for_read[z]&0xf0);
		}
		print_string_2d(suffixes_for_read, read_length);
		bitonic_sort(suffixes_for_read);
			//cout<<**suffixes_for_read <<endl;
        //sort_fourbit_suffixes(suffixes_for_read, read_length, read_length/2);
        for(int j=0;j<read_length;j++){
            fourbit_sorted_suffixes_student[i*read_length+j] = suffixes_for_read[j];
        }
    }
	
	

    //--------------For debug purpose--------------
    /*
    for(int i=0;i<read_count*read_length;i++){
        for(int j=0;j<read_length/2;j++)
            printf("%x\t",fourbit_sorted_suffixes_original[i][j]);
        printf("\n");
    }*/
    //---------------------------------------------
}

//--------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------


//-----------------------DO NOT CHANGE AT ALL--------------------------------------------



//This array is the default result



//Read file to get reads
char** inputReads(char *file_path, int *read_count, int *length){
    FILE *read_file = fopen(file_path, "r");
    int ch, lines=0;
    char **reads;
    do                                                                                                 
    {                                                                                                  
        ch = fgetc(read_file);                                                                            
        if (ch == '\n')                                                                                
            lines++;                                                                                   
    } while (ch != EOF);
    rewind(read_file);
    reads=(char**)malloc(lines*sizeof(char*));
    *read_count = lines;
    int i = 0;                                                                                         
    size_t len = 0;                                                                                    
    for(i = 0; i < lines; i++)                                                                         
    {
        reads[i] = NULL;
        len = 0;                                                                                
        getline(&reads[i], &len, read_file);
    }                                                                                                  
    fclose(read_file);
    int j=0;
    while(reads[0][j]!='\n')
        j++;
    *length = j+1;
    for(i=0;i<lines;i++)
        reads[i][j]='$';
    return reads;
}

//Check correctness of values
int checker(){
    int correct = 1;
    for(int i=0;i<read_count*read_length;i++){
        for(int j=0;j<read_length/2;j++){
            if(fourbit_sorted_suffixes_student[i][j] != fourbit_sorted_suffixes_original[i][j])
                correct = 0;
        }
    }
    return correct;
}

//Rotate 4-bit encoded read by 1 character (4-bit)
char* rotateRead(char *read, int byte_length){
    char prev_4bit = (read[0] & 0x0F) << 4;
    read[0] = (read[0] >> 4) & 0x0F;
    for(int i=1;i<byte_length;i++){
        char this_char = ((read[i] >> 4) & 0x0F) | prev_4bit;
        prev_4bit = (read[i] & 0x0F) << 4;
        read[i] = this_char;
    }
    read[0]=read[0] | prev_4bit;
    char *rotated_read = (char*)malloc(byte_length*sizeof(char));
    for(int i=0;i<byte_length;i++)
        rotated_read[i] = read[i];
    return rotated_read;
}


//Generate Sufixes for a 4-bit encoded read
char** generateSuffixes(char *read, int byte_length){
    char **suffixes=(char**)malloc(byte_length*2*sizeof(char*));
    for(int i=0;i<byte_length*2;i++){
        suffixes[i] = rotateRead(read, byte_length);
    }
    return suffixes;
}

//Comparator for 4-bit encoded Suffixes
int compSuffixes(char *suffix1, char *suffix2, int byte_length){
    int ret = 0;
    for(int i=0;i<byte_length;i++){
        if(suffix1[i]>suffix2[i])
            return 1;
        else if(suffix1[i]<suffix2[i])
            return -1;
    }
    return ret;
}

char* fourbitEncodeRead(char *read, int length){
    int byte_length = length/2;
    char *fourbit_read = (char*)calloc(byte_length,sizeof(char));
    for(int i=0;i<length;i++){
        char this_char = read[i];
        char fourbit_char;
        if(this_char == '$')
            fourbit_char = 0x00;
        else if(this_char == 'A')
            fourbit_char = 0x01;
        else if(this_char == 'C')
            fourbit_char = 0x02;
        else if(this_char == 'G')
            fourbit_char = 0x03;
        else
            fourbit_char = 0x04;
        fourbit_char = i%2==0 ? fourbit_char << 4 : fourbit_char;
        fourbit_read[i/2] = fourbit_read[i/2] | fourbit_char;
    }
   return fourbit_read;
}

void sort_fourbit_suffixes(char **suffixes, int suffix_count, int byte_length){
    char *temp=(char*)malloc(byte_length*sizeof(char));
    for(int i=0;i<suffix_count-1;i++){
        for(int j=0;j<suffix_count-i-1;j++){
            if(compSuffixes(suffixes[j], suffixes[j+1], byte_length)>0){
                memcpy(temp, suffixes[j], byte_length*sizeof(char));
                memcpy(suffixes[j], suffixes[j+1], byte_length*sizeof(char));
                memcpy(suffixes[j+1], temp, byte_length*sizeof(char));
            }
            
        }
    }
}

//Default Pipeline. You need to implement CUDA function corresponding to everything inside this function
void pipeline(char **reads, int read_length, int read_count){
    fourbit_sorted_suffixes_original = (char**)malloc(read_length*read_count*sizeof(char*));
    for(int i=0;i<read_count;i++){
        char **suffixes_for_read = generateSuffixes(fourbitEncodeRead(reads[i], read_length), read_length/2);
        sort_fourbit_suffixes(suffixes_for_read, read_length, read_length/2);

        for(int j=0;j<read_length;j++){
            fourbit_sorted_suffixes_original[i*read_length+j] = suffixes_for_read[j];
        }
    }
    //--------------For debug purpose--------------
    /*
    for(int i=0;i<read_count*read_length;i++){
        for(int j=0;j<read_length/2;j++)
            printf("%x\t",fourbit_sorted_suffixes_original[i][j]);
        printf("\n");
    }*/
    //---------------------------------------------
}

//Merge all sorted suffixes in overall sorted order
void mergeAllSorted4bitSuffixes(char** suffixes, int read_count, int read_length){

}

//-----------------------DO NOT CHANGE--------------------------------------------

int main(int argc, char *argv[]){
    char **reads = inputReads(argv[1], &read_count, &read_length);//Input reads from file

    //-----------Default implementation----------------
    //-----------Time capture start--------------------
    struct timeval  TimeValue_Start;
    struct timeval  TimeValue_Final;
    struct timezone TimeZone_Start;
    struct timezone TimeZone_Final;
    long time_start, time_end;
    double time_overhead_default, time_overhead_student;

    gettimeofday(&TimeValue_Start, &TimeZone_Start);
    pipeline(reads, read_length, read_count);
    mergeAllSorted4bitSuffixes(fourbit_sorted_suffixes_original, read_count, read_length);

    gettimeofday(&TimeValue_Final, &TimeZone_Final);
    time_start = TimeValue_Start.tv_sec * 1000000 + TimeValue_Start.tv_usec;
    time_end = TimeValue_Final.tv_sec * 1000000 + TimeValue_Final.tv_usec;
    time_overhead_default = (time_end - time_start)/1000000.0;
    cout<<time_overhead_default<<endl;
    //------------Time capture end----------------------
    //--------------------------------------------------


    //-----------Your implementations------------------
    gettimeofday(&TimeValue_Start, &TimeZone_Start);
    time_start = TimeValue_Start.tv_sec * 1000000 + TimeValue_Start.tv_usec;
    //-----------Call your functions here--------------------
	cout<<"pipeline_stu"<<endl;
	pipeline_stu(reads, read_length, read_count);

    //-----------Call your functions here--------------------
    time_end = TimeValue_Final.tv_sec * 1000000 + TimeValue_Final.tv_usec;
    time_overhead_student = (time_end - time_start)/1000000.0;
    //--------------------------------------------------


    //---------------Correction check and speedup calculation----------------------
#if 0
    float speedup=0.0;
    if(checker()==1)
        speedup = time_overhead_default/time_overhead_student;
    cout<<"Speedup="<<speedup<<endl;
    //-----------------------------------------------------------------------------
#endif
    return 0;
}
