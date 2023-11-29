/* 
 * Course: High Performance Computing 2021/2022
 * 
 * Lecturer: Francesco Moscato	fmoscato@unisa.it
 *
 * Group:
 * Salvatore Grimaldi       0622701742      s.grimaldi29@studenti.unisa.it              
 * Enrico Maria Di Mauro    0622701706      e.dimauro5@studenti.unisa.it
 * Allegra Cuzzocrea        0622701707      a.cuzzocrea2@studenti.unisa.it
 * 
 * 
 * Copyright (C) 2021 - All Rights Reserved 
 *
 * This file is part of Contest-CUDA.
 *
 * Contest-CUDA is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Contest-CUDA is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Contest-CUDA.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
  @file shared.cu
  @brief This is the file shared.cu, which contains the main function and the other functions
  @copyright Copyright (c) 2021
*/

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <time.h>
#include <math.h>
#include <curand.h>
#include <curand_kernel.h>
#define MAXBLOCKSIZE 1024 //by Tesla K80 documentation

//useful macro for error handling
#define CUDA_CHECK(X)                                               \
  {                                                                 \
    cudaError_t _m_cudaStat = X;                                    \
    if (cudaSuccess != _m_cudaStat)                                 \
    {                                                               \
      fprintf(stderr, "\nErrorCuda: %s in file %s line %d\n",       \
              cudaGetErrorString(_m_cudaStat), __FILE__, __LINE__); \
      exit(1);                                                      \
    }                                                               \
  }

/**
 * @brief This is the kernel that creates random numbers and insert them in 'arrayA'.
 * @param arrayA      pointer to the unsorted array.
 * @param n           number of array elements.
 * @param range       maximum acceptable integer.
 * @param seed        seed of random number.
 */
__global__ void gpu_initArray(int *arrayA, int n, int range, int seed)
{
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  curandState_t state;
  curand_init(seed + i, 0, 0, &state);
  if (i >= n)
    return; //don't go beyond array limit
  arrayA[i] = curand(&state) % (range + 1);
}

/**
 * @brief This is the kernel that fulls 'arrayC' adding 1 to 'arrayC' positions which correspond to 'arrayA' elements.
 * @param arrayA      pointer to the unsorted array.
 * @param arrayC      pointer to the auxiliary array.
 * @param n           number of array elements.
 */
__global__ void gpu_fullC(int *arrayA, int *arrayC, int n, int lenC)
{
  extern __shared__ int C_shared[];

  int tid = threadIdx.x;
  for (int i = tid; i < lenC; i += blockDim.x)
    C_shared[i] = 0;
  __syncthreads();

  int input_idx = blockIdx.x * blockDim.x + tid;
  if (input_idx < n)
    atomicAdd(&C_shared[arrayA[input_idx]], 1);
  __syncthreads();

  for (int i = tid; i < lenC; i += blockDim.x)
    atomicAdd(&arrayC[i], C_shared[i]);
}

/**
 * @brief This is the kernel that sums every 'arrayC' element with the previous one.
 * @param arrayC      pointer to the auxiliary array.
 * @param len         number of array elements.
 */
__global__ void gpu_sumC(int *arrayC, int len)
{
  for (int i = 1; i < len; i++)
    arrayC[i] += arrayC[i - 1];
}

/**
 * @brief This is the kernel that sorts 'arrayA' using 'arrayC' and puts the result in 'sorted'.
 * @param arrayA      pointer to the unsorted array.
 * @param arrayC      pointer to the auxiliary array.
 * @param sorted      pointer to the sorted array.
 * @param n           number of array elements.
 */
__global__ void gpu_lastKernel(int *arrayA, int *arrayC, int *sorted, int n)
{
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= n)
    return;
  int num = arrayA[i];
  int app = atomicSub(&arrayC[num], 1); //'app' holds old arrayC[num] value (before atomicSub)
  sorted[app - 1] = num;
}

/**
 * @brief This is the function that creates and initializes a random array, calling the appropriate kernel, and puts it in 'array_h'.
 * @param array_h       pointer to the unsorted array.
 * @param n             number of array elements.
 * @param range         maximum acceptable integer.
 * @param blockSize     number of threads in each block.
 */
float initArray(int *array_h, int n, int range, int blockSize)
{
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  cudaEventRecord(start, 0);

  int *array_d; //device array

  CUDA_CHECK(cudaMalloc((void **)&array_d, n * sizeof(int)));

  dim3 block(blockSize);
  dim3 grid((n - 1) / block.x + 1);

  cudaError_t myCudaError;
  myCudaError = cudaGetLastError(); //call done to reset previous CUDA errors

  //calling kernel to initialize array
  gpu_initArray<<<grid, block>>>(array_d, n, range, time(NULL));

  cudaDeviceSynchronize(); //sync host and device
  myCudaError = cudaGetLastError();
  if (myCudaError != cudaSuccess)
    printf("ERROR IN gpu_initArray\n%s\n", cudaGetErrorString(myCudaError));

  cudaEventRecord(stop, 0);
  cudaEventSynchronize(stop);
  float elapsed;
  cudaEventElapsedTime(&elapsed, start, stop); //elapsed is the time in ms (milliseconds)
  cudaEventDestroy(start);
  cudaEventDestroy(stop);

  //copy to host array
  CUDA_CHECK(cudaMemcpy(array_h, array_d, n * sizeof(int), cudaMemcpyDeviceToHost));

  CUDA_CHECK(cudaFree(array_d));

  return elapsed;
}

/**
 * @brief This is the function that sorts 'array_h' using Counting Sort algorithm on the GPU.
 * @param array_h       pointer to the unsorted array.
 * @param n             number of array elements.
 * @param max           maximum acceptable integer.
 * @param blockSize     number of threads in each block.
 */
float countingSortDEVICE(int *array_h, int n, int max, int blockSize)
{
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  cudaEventRecord(start, 0);

  int *array_d;  //device array
  int *C_d;      //device array C
  int *sorted_d; //device array sorted
  int lenC = max + 1;

  CUDA_CHECK(cudaMalloc((void **)&array_d, n * sizeof(int)));
  CUDA_CHECK(cudaMemcpy(array_d, array_h, n * sizeof(int), cudaMemcpyHostToDevice));

  CUDA_CHECK(cudaMalloc((void **)&C_d, lenC * sizeof(int)));
  CUDA_CHECK(cudaMemset(C_d, 0, lenC * sizeof(int))); //initialize to 0

  CUDA_CHECK(cudaMalloc((void **)&sorted_d, n * sizeof(int)));

  dim3 block(blockSize);
  dim3 grid((n - 1) / block.x + 1);

  cudaError_t myCudaError;
  myCudaError = cudaGetLastError(); //call done to reset previous CUDA errors

  gpu_fullC<<<grid, block, sizeof(int) * lenC>>>(array_d, C_d, n, lenC);

  cudaDeviceSynchronize(); //sync host and device
  myCudaError = cudaGetLastError();
  if (myCudaError != cudaSuccess)
    printf("ERROR IN gpu_fullC()\n%s\n", cudaGetErrorString(myCudaError));

  gpu_sumC<<<1, 1>>>(C_d, lenC);

  cudaDeviceSynchronize();
  myCudaError = cudaGetLastError();
  if (myCudaError != cudaSuccess)
    printf("ERROR IN gpu_sumC()\n%s\n", cudaGetErrorString(myCudaError));

  gpu_lastKernel<<<grid, block>>>(array_d, C_d, sorted_d, n);

  cudaDeviceSynchronize();
  myCudaError = cudaGetLastError();
  if (myCudaError != cudaSuccess)
    printf("ERROR IN gpu_lastKernelC()\n%s\n", cudaGetErrorString(myCudaError));

  CUDA_CHECK(cudaMemcpy(array_h, sorted_d, n * sizeof(int), cudaMemcpyDeviceToHost));

  CUDA_CHECK(cudaFree(array_d));
  CUDA_CHECK(cudaFree(C_d));
  CUDA_CHECK(cudaFree(sorted_d));

  cudaEventRecord(stop, 0);
  cudaEventSynchronize(stop);
  float elapsed;
  cudaEventElapsedTime(&elapsed, start, stop); //elapsed is the time in ms (milliseconds)
  cudaEventDestroy(start);
  cudaEventDestroy(stop);

  return elapsed;
}

/**
 * @brief This is the function that sorts 'array' using Counting Sort algorithm on the CPU.
 * @param array         pointer to the unsorted array.
 * @param n             number of array elements.
 * @param max           maximum acceptable integer.
 */
void countingSortHOST(int *array, int n, int max)
{
  int *b;
  int *c;
  int i;
  int lenC = max + 1;

  b = (int *)malloc(n * sizeof(int));
  c = (int *)malloc(lenC * sizeof(int));

  for (i = 0; i < lenC; i++)
    c[i] = 0;

  for (i = 0; i < n; i++)
    c[array[i]] += 1;

  for (i = 1; i < lenC; i++)
    c[i] += c[i - 1];

  int num;
  for (i = 0; i < n; i++)
  {
    num = array[i];
    c[num] -= 1;
    b[c[num]] = num;
  }

  for (i = 0; i < n; i++)
  {
    array[i] = b[i];
  }

  free(b);
  free(c);
}

/**
 * @brief This is the function that creates a file ".csv" which contains values for 'blockSize', 'gridSize', 'elapsedInit', 'elapsedSort'.
 * @param blockSize       number of threads in each block.
 * @param elapsedInit     time to initialize the array.       
 * @param elapsedSort     time to sort the array
 * @param n               number of array elements.
 * @param range           maximum acceptable integer.
 */
void make_csv(int blockSize, float elapsedInit, float elapsedSort, int n, int range)
{
  FILE *fp;
  char root_filename[] = "shared_measure";
  char *filename = (char *)malloc(sizeof(char) * (strlen(root_filename) + 16 * sizeof(char)));
  sprintf(filename, "%s_%d_%d.csv", root_filename, n, range);
  if (access(filename, F_OK) == 0)
    fp = fopen(filename, "a");
  else
  {
    fp = fopen(filename, "w");
    fprintf(fp, "blockSize;gridSize;elapsedInit;elapsedSort\n");
  }
  fprintf(fp, "%d;%d;%f;%f\n", blockSize, ((n - 1) / blockSize + 1), elapsedInit / 1000, elapsedSort / 1000);
  fclose(fp);
  free(filename);
}

int main(int argc, char *argv[])
{
  int n;         //array length
  int range;     //range = max integer in array
  int blockSize; //threads per block
  int *array_h;  //host array
  int *array2_h; //host second array
  int i;
  float elapsedInit;
  float elapsedSort;

  if (argc != 4)
  {
    fprintf(stderr, "ERROR! YOU MUST INSERT ARRAY LENGTH, RANGE AND BLOCKSIZE\n");
    exit(EXIT_FAILURE);
  }

  n = atoi(argv[1]);
  range = atoi(argv[2]);
  blockSize = atoi(argv[3]);

  if (blockSize <= 0 || blockSize > MAXBLOCKSIZE)
  {
    fprintf(stderr, "ERROR! BLOCKSIZE NOT ACCEPTABLE\n");
    exit(EXIT_FAILURE);
  }

  //allocate memory on host
  array_h = (int *)malloc(n * sizeof(int));
  if (array_h == NULL)
  {
    fprintf(stderr, "ERROR! COULD NOT GET MEMORY FOR array_h\n");
  }

  array2_h = (int *)malloc(n * sizeof(int));
  if (array2_h == NULL)
  {
    fprintf(stderr, "ERROR! COULD NOT GET MEMORY FOR array2_h\n");
  }

  elapsedInit = initArray(array_h, n, range, blockSize);

  for (i = 0; i < n; i++)
    array2_h[i] = array_h[i];

  //after calling countingSort, array_h is finally sorted
  elapsedSort = countingSortDEVICE(array_h, n, range, blockSize);

  countingSortHOST(array2_h, n, range);

  for (i = 0; i < n; i++)
  {
    if (array_h[i] != array2_h[i])
    {
      printf("TEST ERROR");
      return (EXIT_FAILURE);
    }
  }

  //make_csv(blockSize, elapsedInit, elapsedSort, n, range);
  printf("%d;%d;%f;%f\n", blockSize, ((n - 1) / blockSize + 1), elapsedInit / 1000, elapsedSort / 1000);

  free(array_h);
  free(array2_h);
}