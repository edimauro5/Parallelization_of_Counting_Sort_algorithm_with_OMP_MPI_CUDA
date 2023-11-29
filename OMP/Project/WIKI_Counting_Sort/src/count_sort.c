/* 
 * Course: High Performance Computing 2021/2022
 * 
 * Lecturer: Francesco Moscato	fmoscato@unisa.it
 *
 * Group:
 * Salvatore Grimaldi  0622701742  s.grimaldi29@studenti.unisa.it              
 * Enrico Maria Di Mauro  0622701706  e.dimauro5@studenti.unisa.it
 * Allegra Cuzzocrea  0622701707  a.cuzzocrea2@studenti.unisa.it
 * 
 * 
 * Copyright (C) 2021 - All Rights Reserved 
 *
 * This file is part of Contest-OMP.
 *
 * Contest-OMP is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Contest-OMP is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Contest-OMP.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
	@file count_sort.c
  @brief This is the file .c that contains the functions that are called in the main
  @copyright Copyright (c) 2021
*/

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "../include/count_sort.h"

#ifdef _OPENMP
#include <omp.h>
#else
#define get_thread_num() 0
#endif

/**
 * @brief This function sorts the array 'a' using Counting Sort Algorithm.
 * @param a          pointer to the unsorted array.
 * @param N          number of array elements.
 */
void countingSort(int *a, int N)
{
  //Calcolo degli elementi max e min
  int max = a[0];
  int min = a[0];
  int i = 1;

#pragma omp parallel
  {
    int local_max = max;
    int local_min = min;
#pragma omp for nowait
    for (int i = 1; i < N; i++)
    {
      int local_result;
      local_result = a[i];
      if (local_result > local_max)
      {
        local_max = local_result;
      }
      else if (local_result < local_min)
      {
        local_min = local_result;
      }
    }
#pragma omp critical
    {
      if (local_max > max)
        max = local_max;
      if (local_min < min)
        min = local_min;
    }
  }

  //Costruzione dell'array C (inizializzazione)
  int *c = (int *)malloc((max - min + 1) * sizeof(int));

#pragma omp parallel for shared(min, max, c) private(i)
  for (i = 0; i < max - min + 1; i++)
    c[i] = 0;

    //Costruzione dell'array C (riempimento)
#pragma omp parallel for shared(min, a, N) private(i) reduction(+ \
                                                                : c[:max - min + 1])
  for (i = 0; i < N; i++)
    c[a[i] - min] += 1;

  //Ordinamento in base al contenuto dell'array delle frequenze C
  int k = 0;
  for (i = 0; i < max - min + 1; i++)
    while (c[i] > 0)
    {
      a[k] = i + min;
      k = k + 1;
      c[i] = c[i] - 1;
    }
  free(c);
}

/**
 * @brief This function generates 'N' random integers and insert them into the array 'a'.
 * @param a           pointer to the array where to insert elements.
 * @param N           number of random integers that have to be generated.
 */
void gen_rand(int *a, int N)
{
  for (int i = 0; i < N; i++)
    a[i] = rand() % 1001;
}