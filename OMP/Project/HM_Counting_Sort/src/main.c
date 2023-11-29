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
	@file main.c
  @brief This is the file main.c, which is the main function that calls the other functions
  @copyright Copyright (c) 2021
*/

#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <time.h>
#include "../include/count_sort.h"

int main(int argc, char *argv[])
{
  double start, end, time;
  int numT = atoi(argv[1]);
  int N = atoi(argv[2]);

#ifdef _OPENMP
  omp_set_num_threads(numT);
#endif

  int *a = (int *)malloc(N * sizeof(int));
  int *c = (int *)malloc(N * sizeof(int));

  gen_rand(a, N);

#ifdef _OPENMP
  start = omp_get_wtime();
#else
  STARTTIME(0);
#endif

  countingSort(a, c, N);

#ifdef _OPENMP
  end = omp_get_wtime();
  time = end - start;
#else
  ENDTIME(0, time);
#endif

  printf("%d;%f;", numT, time);
  free(a);
  free(c);
  return 0;
}