#include <iostream>
#include <fstream>
#include <iomanip>
#include <cstring>
#include <cmath>
#include <stdlib.h>
#include <sys/time.h>

using namespace std;
int **L_counts;
int compSuffixes(char *suffix1, char *suffix2, int length);

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

void print_string_2d(char **str, int len , int cnt){
	printf("=== string address ===\n");
	printf("\n");
	for (int i = 0; i < 2 * len; i++) {
		printf(" %X", i);
	}
	printf("\n============== 2d print ==============\n");
	printf("============== read_count = %d ==============\n",read_count);

	for (int i = 0; i < len*cnt; i++) {
		for (int z = 0; z < len/2; z++){
			printf("%c%c", ctable[str[i][z]>>4], ctable[str[i][z] &0xF]);
			//fout<<ctable[str[i][z]>>4]<<ctable[str[i][z] &0xF];
		}
		printf("\n");
		//fout<<"\n";
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
			printf("%c%c", ctable[str[(i*len/2+z)]>>4 ], ctable[str[i*len/2+z] &0xF]);
		}
		printf("\n");
	}
	printf("\n============== 1d print ==============\n");
}
__global__ void fourbitEncodeRead_gpu(char *dev_read, int length, int i){

	char this_char = dev_read[i];
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
	dev_read[i/2] = dev_read[i/2] | fourbit_char;

}

char* fourbitEncodeRead_stu(char *read, int length){
    int byte_length = length/2;
    char *fourbit_read = (char*)calloc(byte_length,sizeof(char));
	char *dev_read;
	cudaMalloc((void**) &dev_read, length*sizeof(char));
	cudaMemcpy(dev_read, read, length*sizeof(char), cudaMemcpyHostToDevice);
	dim3 blocks(BLOCKS,1);    /* Number of blocks   */
    dim3 threads(THREADS,1);  /* Number of threads  */
    for(int i=0;i<length;i++){
        fourbitEncodeRead_gpu <<<blocks, threads>>> (dev_read, length , i);
    }
	cudaMemcpy(fourbit_read, dev_read, byte_length*sizeof(char) , cudaMemcpyDeviceToHost);
	cudaFree(dev_read);
   return fourbit_read;
}

__global__ void rotateRead_gpu_part1(char *dev_read, int i , char prev_4bit){
	char this_char = ((dev_read[i] >> 4) & 0x0F) | prev_4bit;
	dev_read[i] = this_char;
}


char* rotateRead_stu(char *read, int byte_length){

    char prev_4bit = (read[0] & 0x0F) << 4;
	char *dev_read;
	dim3 blocks(BLOCKS,1);
    dim3 threads(THREADS,1);
	cudaMalloc((void**) &dev_read, byte_length*sizeof(char));
	cudaMemcpy(dev_read, read, byte_length*sizeof(char), cudaMemcpyHostToDevice);
    for(int i=1;i<byte_length;i++){
		rotateRead_gpu_part1 <<<blocks, threads>>> (dev_read , i , (read[i-1] & 0x0F) << 4);
    }
	prev_4bit = (read[byte_length-1] & 0x0F) << 4;
	cudaMemcpy(read, dev_read, byte_length*sizeof(char) , cudaMemcpyDeviceToHost);
	cudaFree(dev_read);
	read[0] = (read[0] >> 4) & 0x0F;
    read[0]=read[0] | prev_4bit;

    char *rotated_read = (char*)malloc(byte_length*sizeof(char));

    for(int i=0;i<byte_length;i++){
        rotated_read[i] = read[i];
	}

    return rotated_read;
}
/*
char* rotateRead_stu(char *read, int byte_length){

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
}*/
//Generate Sufixes for a 4-bit encoded read
char** generateSuffixes_stu(char *read, int byte_length){

	fourbitEncodeRead_stu(read, read_length);

    char **suffixes=(char**)malloc(byte_length*2*sizeof(char*));
    for(int i=0;i<byte_length*2;i++){
        suffixes[i] = rotateRead_stu(read, byte_length);
    }
    return suffixes;
}



__global__ void bitonic_sort_step(char *dev_values, int j, int k, int num_value, int read_length, int read_count){
    //printf(">>> bitonic_sort_step\n");
    int flag = 0;
	int HIGH = 0;
	unsigned int i, ixj; /* Sorting partners: i and ixj */
    i = threadIdx.x + blockDim.x * blockIdx.x;
    ixj = i^j;
    char temp_char_i,temp_char_ixj;
	//printf("input string = %s\n",dev_values);
    /* The threads with the lowest ids sort the array. */
    flag = 0;
    if ((ixj)>i) {
        for(int l=0;l<read_length;l++){
			if (HIGH) {
				temp_char_i   = dev_values[i  *read_length / 2 + l / 2] & (0xF);
				temp_char_ixj = dev_values[ixj*read_length / 2 + l / 2] & (0xF);
			} else {
				temp_char_i   = (dev_values[i  *read_length / 2 + l / 2]& (0xF0)) >>4;
				temp_char_ixj = (dev_values[ixj*read_length / 2 + l / 2]& (0xF0)) >>4;
			}

			if (temp_char_i>temp_char_ixj){
				flag = 1;
                break;
            } else if(temp_char_i<temp_char_ixj){
                flag = -1;
                break;
            }
            HIGH = !HIGH;

        }
        //printf("i=%d, ixj=%d, sorting result flag = %d\n",i,ixj,flag);


        if ((i&k)==0) {
            // Sort ascending //
            if (flag==1) {
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
void bitonic_sort(char **values, fstream& fout){
    char *dev_values;
    size_t size = read_length/2 * sizeof(char);
    char *temp;
    char *temp_char = new char[read_length/2];


    temp = (char*)malloc(num_value*size);
    for(int i=0;i<read_length/2;i++){
        temp_char[i]=0x44;
    }
	for (int i = 0; i < num_value; i++){
        if (i < read_length * read_count){
            memcpy(&temp[i*read_length/2], values[i], size);
        }
        else{
            memcpy(&temp[i*read_length/2], temp_char , 	size);
        }
    }
	free(temp_char);
	//printf("001\n");
    cudaMalloc((void**) &dev_values, size*num_value);

    cudaMemcpy(dev_values, temp, num_value*size, cudaMemcpyHostToDevice);
	//cout<<"================debug======================"<<endl;
	//print_string_1d(temp,read_length);
    dim3 blocks(BLOCKS,1);    /* Number of blocks   */
    dim3 threads(THREADS,1);  /* Number of threads  */
	//cout<<"=========== before temp ==========="<<endl;
	//print_string_1d (temp,read_length);
	//cout<<"=========== after temp ==========="<<endl;
    int j, k;
    /* Major step */

    for (k = 2; k <= num_value; k <<= 1) {
        //* Minor step */
        for (j=k>>1; j>0; j=j>>1) {
			bitonic_sort_step<<<blocks, threads>>>(dev_values, j, k, num_value,read_length, read_count);
			//bitonic_sort_step<<<blocks, threads>>>(dev_values, j, k, num_value,read_length, 1);
		}
    }

    cudaMemcpy(temp, dev_values, read_length*read_count*size, cudaMemcpyDeviceToHost);
    //cudaMemcpy(temp, dev_values, read_length*1*size, cudaMemcpyDeviceToHost);

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
	//print_string_2d(fourbit_sorted_suffixes_student, read_length,read_count);
    //cout<<"begin teeeeeeeeeeeeeeeeeeeeeeeeeeeeeemp"<<endl;


	free(temp);
    cudaFree(dev_values);
}


void pipeline_stu(char **reads, int read_length, int read_count, fstream& fout){
	int temp_stu = ceil(log2((float)read_length*read_count));

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
		//cout << "read_length = " << read_length << endl;

		//bitonic_sort(suffixes_for_read);

        for(int j=0;j<read_length;j++){
            fourbit_sorted_suffixes_student[i*read_length+j] = suffixes_for_read[j];
        }
		free(suffixes_for_read);
    }
	cout<<"=========== before bitonic_sort ==========="<<endl;
	//print_string_2d(fourbit_sorted_suffixes_student, read_length,read_count, fout);
	cout<<"=========== into bitonic_sort ==========="<<endl;
	bitonic_sort(fourbit_sorted_suffixes_student, fout);


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
int **SA_Final;
char *L;
int F_counts[]={0,0,0,0};

//This array is the default result



//Read file to get reads
char** inputReads(const char *file_path, int *read_count, int *length){//same
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
	//print_string_2d(fourbit_sorted_suffixes_student, read_length,read_count);
    //print_string_2d(fourbit_sorted_suffixes_original, read_length,read_count);

	for(int i=0;i<read_count*read_length;i++){
        for(int j=0;j<read_length/2;j++){
            if(fourbit_sorted_suffixes_student[i][j] != fourbit_sorted_suffixes_original[i][j]){
				correct = 0;
				/*cout<<"wrong i="<<i<<" wrong j = "<<j<<endl;
				print_string_1d(fourbit_sorted_suffixes_student[i],read_length);*/
				//print_string_1d(fourbit_sorted_suffixes_original[i],read_length);
			}
        }
    }
    return correct;
}

//Rotate 4-bit encoded read by 1 character (4-bit)
char* rotateRead(char *read, int byte_length){//rotateRead_2
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
void rotateRead_2(char *read, char *rotatedRead, int length){//2
    for(int i=0;i<length-1;i++)
        rotatedRead[i]=read[i+1];
    rotatedRead[length-1]=read[0];
}


//Generate Sufixes for a 4-bit encoded read
char** generateSuffixes(char *read, int byte_length){//generateSuffixes_2
    char **suffixes=(char**)malloc(byte_length*2*sizeof(char*));
    for(int i=0;i<byte_length*2;i++){
        suffixes[i] = rotateRead(read, byte_length);
    }
    return suffixes;
}
char** generateSuffixes_2(char *read, int length, int read_id){//2
    char **suffixes=(char**)malloc(length*sizeof(char*));
    suffixes[0]=(char*)malloc(length*sizeof(char));
    for(int j=0;j<length;j++)
        suffixes[0][j]=read[j];
    for(int i=1;i<length;i++){
        suffixes[i]=(char*)malloc(length*sizeof(char));
        rotateRead_2(suffixes[i-1], suffixes[i], length);
    }
    return suffixes;
}

//Comparator for 4-bit encoded Suffixes
int compSuffixes(char *suffix1, char *suffix2, int byte_length){//same
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
	free(temp);
}

int** makeFMIndex(char ***suffixes, int read_count, int read_length, int F_count[], char *L){//2
    int i, j;

    SA_Final=(int**)malloc(read_count*read_length*sizeof(int*));
    for(i=0;i<read_count*read_length;i++)
        SA_Final[i]=(int*)malloc(2*sizeof(int));

    //Temporary storage for collecting together all suffixes
    char **temp_suffixes=(char**)malloc(read_count*read_length*sizeof(char*));

    //Initalization of temporary storage
    for(i=0;i<read_count;i++){
        for(j=0;j<read_length;j++){
            temp_suffixes[i*read_length+j]=(char*)malloc(read_length*sizeof(char));
            memcpy(&temp_suffixes[i*read_length+j], &suffixes[i][j],read_length*sizeof(char));
            SA_Final[i*read_length+j][0]=j;
            SA_Final[i*read_length+j][1]=i;
        }
    }

    char *temp=(char*)malloc(read_length*sizeof(char));

    int **L_count=(int**)malloc(read_length*read_count*sizeof(int*));
    for(i=0;i<read_length*read_count;i++){
        L_count[i]=(int*)malloc(4*sizeof(int));
        for(j=0;j<4;j++){
            L_count[i][j]=0;
        }
    }


    //Focus on improving this for evaluation purpose
    //Sorting of suffixes
    for(i=0;i<read_count*read_length-1;i++){
        for(j=0;j<read_count*read_length-i-1;j++){
            if(compSuffixes(temp_suffixes[j], temp_suffixes[j+1], read_length)>0){
                memcpy(temp, temp_suffixes[j], read_length*sizeof(char));
                memcpy(temp_suffixes[j], temp_suffixes[j+1], read_length*sizeof(char));
                memcpy(temp_suffixes[j+1], temp, read_length*sizeof(char));
                int temp_int = SA_Final[j][0];
                SA_Final[j][0]=SA_Final[j+1][0];
                SA_Final[j+1][0]=temp_int;
                temp_int = SA_Final[j][1];
                SA_Final[j][1]=SA_Final[j+1][1];
                SA_Final[j+1][1]=temp_int;
            }
        }
    }

    free(temp);
    char this_F = '$';
    j=0;

    //Calculation of F_count's
    for(i=0;i<read_count*read_length;i++){
        int count=0;
        while(temp_suffixes[i][0]==this_F){
            count++;i++;
        }
        F_count[j++]=j==0?count:count+1;
        this_F = temp_suffixes[i][0];
        if(temp_suffixes[i][0]=='T')
            break;
    }

    //Calculation of L's and L_count's
    for(i=0;i<read_count*read_length;i++){
        char ch = temp_suffixes[i][read_length-1];
        L[i]=ch;
        if(i>0){
            for(int k=0;k<4;k++)
                L_count[i][k]=L_count[i-1][k];
        }
        if(ch=='A')
            L_count[i][0]++;
        else if(ch=='C')
            L_count[i][1]++;
        else if(ch=='G')
            L_count[i][2]++;
        else if(ch=='T')
            L_count[i][3]++;
    }
	//for(int i=0; i<read_count*read_length; ++i) free(temp_suffixes[i]);
	free(temp_suffixes);
    return L_count;
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

// void Merge(char** suffixes, int front, int mid, int end){
	// char** LeftSub = (char**) malloc((mid-front+1+1)*sizeof(char*));
	// char** RightSub = (char**) malloc((end-mid+1)*sizeof(char*));
	// char* MAXchar = (char*) malloc(read_length/2*sizeof(char));
	// for(int i=0; i<read_length/2; ++i)
		// MAXchar[i] = 0x44;
	// memcpy(LeftSub[mid-front+1+1-1], MAXchar, sizeof(char*));
	// memcpy(LeftSub[end-mid+1-1], MAXchar, sizeof(char*));
	// memcpy(LeftSub, &suffixes[front], (mid-front+1)*sizeof(char*));
	// memcpy(LeftSub, &suffixes[front], (mid-front+1)*sizeof(char*));

    // int idxLeft = 0, idxRight = 0;

    // for (int i = front; i <= end; i++) {

        // if (LeftSub[idxLeft] <= RightSub[idxRight] ) {
            // Array[i] = LeftSub[idxLeft];
            // idxLeft++;
        // }
        // else{
            // Array[i] = RightSub[idxRight];
            // idxRight++;
        // }
    // }
// }
//Merge all sorted suffixes in overall sorted order
// void mergeAllSorted4bitSuffixes(char** suffixes, int read_count, int read_length){
	// int flag = 0;
	// int HIGH = 0;
    // char temp_char_i,temp_char_j;
	// for(int i=0;i<read_count;i++)
		// for(int j=0;j<read_length;j++){
			// for(int k=i+j*read_length;k<read_count*read_length;k++){
				// for(int l=0;l<read_length;l++){
					// if (HIGH)        temp_char_i   = suffixes[i*read_length/2+l/2]&(0xF);
					// else if(!HIGH)    temp_char_i   = (suffixes[i*read_length/2+l/2]&(0xF0))>>4;
					// if (HIGH)      temp_char_j = suffixes[j*read_length/2+l/2]&(0xF);
					// else if (!HIGH) temp_char_j = (suffixes[j*read_length/2+l/2]&(0xF0))>>4;
					// if(temp_char_i>temp_char_j){
						// flag = 1;
						// break;
					// }
					// else if(temp_char_i<temp_char_j){
						// flag = -1;
						// break;
					// }
					// HIGH = !HIGH;
					// flag = 0;
				// }
			// }
			// if()
		// }
// }

//-----------------------DO NOT CHANGE--------------------------------------------


int main(int argc, char *argv[]){
	char **reads;
	cout << "argc\t= " << argc <<endl;
	cout << "argv[0]\t= " << argv[0] <<endl;

	if (argc > 1) {
		cout << "argv[1]\t= " << argv[1] <<endl;
		reads = inputReads(argv[1], &read_count, &read_length); // Input reads from file
	} else
		reads = inputReads("small.txt", &read_count, &read_length); // Input reads from default file "small.txt"

	cout<<"test00"<<endl;

    //-----------Default implementation----------------
    //-----------Time capture start--------------------
    struct timeval  TimeValue_Start;
    struct timeval  TimeValue_Final;
    struct timezone TimeZone_Start;
    struct timezone TimeZone_Final;
    long time_start, time_end;
    double time_overhead_default, time_overhead_student;
	cout<<"test1"<<endl;
    char ***suffixes=(char***)malloc(read_count*sizeof(char**));//Storage for read-wise suffixes
	char **suffixes_encode=(char**)malloc(read_count*read_length*sizeof(char*));
	for(int i=0; i<read_count*read_length; ++i)suffixes_encode[i] = (char*)malloc(read_length/2*sizeof(char));
	cout<<"test2"<<endl;
    L=(char*)malloc(read_count*read_length*sizeof(char*));//Final storage for last column of sorted suffixes
	cout<<"test3"<<endl;
    gettimeofday(&TimeValue_Start, &TimeZone_Start);
    // pipeline(reads, read_length, read_count);
    // mergeAllSorted4bitSuffixes(fourbit_sorted_suffixes_original, read_count, read_length);
    for(int i=0;i<read_count;i++){
        suffixes[i]=generateSuffixes_2(reads[i], read_length, i);
        //suffixes[i]=generateSuffixes(reads[i], read_length);
    }
    L_counts = makeFMIndex(suffixes, read_count, read_length, F_counts, L);
	free(L_counts);
	cout<<"test4-------------------------------------------------------------------"<<endl;

	fstream fout;
	fout.open("s1.txt", ios::out);
	for(int i=0; i<read_count; ++i){
		for(int j=0; j<read_length; ++j){
			//fprintf(stderr,"==============debug=========== %d %d \n",i , j);
			memcpy(suffixes_encode[i*read_length+j],fourbitEncodeRead(suffixes[i][j],read_length),read_length/2*sizeof(char));
			//cout<<suffixes[i][j]<<endl;
		}
	}
	fourbit_sorted_suffixes_original = suffixes_encode;
	fout.close();

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

	//fout.open("s2.txt", ios::out);
	pipeline_stu(reads, read_length, read_count, fout);
	cout<<"test5"<<endl;
	//fout.close();

    //-----------Call your functions here--------------------
    gettimeofday(&TimeValue_Final, &TimeZone_Final);
	time_end = TimeValue_Final.tv_sec * 1000000 + TimeValue_Final.tv_usec;
    time_overhead_student = (time_end - time_start)/1000000.0;
    //--------------------------------------------------


    //---------------Correction check and speedup calculation----------------------

    float speedup=0.0;
    if(checker()==1){
		cout<<"checker()==1"<<endl;
	}
    //speedup = time_overhead_default/time_overhead_student;
    speedup = time_overhead_default/time_overhead_student;
	cout<<"Speedup="<<speedup<<endl;
    //-----------------------------------------------------------------------------

    return 0;
}
