# Contest - OMP

## Dependencies

* CMake 3.9+
* OpenMP
* Python3
* Pipenv

## How to run

Since 2 versions of Counting Sort are provided, you must use command
cd WIKI_Counting_Sort or cd HM_Counting_Sort in order to choose the version to run and:

1.	Create a build directory and launch cmake
    mkdir build
    cd build
    cmake ..

2.	Generate executables with make

3.	To generate measures, run make generate_measures

    Attention: it takes a lot of time. This is the reason why our measures are already included, so you should skip this step.

4.	To extract mean times and speedup curves from them run make extract_measures

Results can be found in the measure/YYYY-MM-DD.hh:mm:ss directory, divided by problem size and the gcc optimization option used.
